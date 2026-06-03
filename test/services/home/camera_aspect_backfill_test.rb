require "test_helper"
require "securerandom"

class Home::CameraAspectBackfillTest < ActiveSupport::TestCase
  setup do
    token = SecureRandom.hex(6)
    @user = User.create!(
      email: "camera-aspect-#{token}@example.com",
      google_uid: "camera-aspect-#{token}",
      name: "Camera Aspect #{token}",
      role: :operator
    )
    @dashboard = Dashboard.fetch_or_create_for!(user: @user, context: :home, name: "Aspect Dashboard")
    @dashboard.update!(settings: { "columns" => 80 })

    provider = ServiceProvider.create!(key: "koala-#{token}", name: "Koala #{token}", provider_type: "hybrid")
    @connection = ServiceConnection.create!(
      service_provider: provider, key: "koala-conn-#{token}", name: "Koala Main #{token}",
      adapter: "koala", credential_strategy: "environment", status: "online"
    )
  end

  test "snaps a legacy camera tile height to a feed-shaped box" do
    tile = camera_tile(width: 20, height: 7)

    Home::CameraAspectBackfill.new(dashboard: @dashboard).run!

    # round(20 / (16/9)) == round(11.25) == 11
    assert_equal 11, tile.reload.height
    assert_equal Home::CameraAspectBackfill::VERSION, @dashboard.reload.settings_hash["camera_aspect_version"]
  end

  test "leaves non-camera tiles untouched" do
    stat = stat_tile(width: 20, height: 20)

    Home::CameraAspectBackfill.new(dashboard: @dashboard).run!

    assert_equal 20, stat.reload.height
  end

  test "is one-time: does not re-run once the version is stamped" do
    tile = camera_tile(width: 20, height: 7)
    @dashboard.update!(settings: @dashboard.settings_hash.merge("camera_aspect_version" => Home::CameraAspectBackfill::VERSION))

    Home::CameraAspectBackfill.new(dashboard: @dashboard).run!

    assert_equal 7, tile.reload.height, "already-stamped dashboards must not be re-snapped"
  end

  private

  def camera_tile(width:, height:)
    device = Device.create!(
      service_connection: @connection, user: @user,
      key: "cam-#{SecureRandom.hex(4)}", name: "CAM", category: "camera",
      source_kind: "physical", source_identifier: "cam", status: "available"
    )
    capability = DeviceCapability.create!(
      device: device, key: "primary_feed", name: "CAM Feed",
      capability_type: "camera_feed",
      configuration: { "camera_id" => "cam" }, state: { "status" => "available" }
    )
    position = @dashboard.dashboard_tiles.maximum(:position).to_i + 1
    tile = @dashboard.dashboard_tiles.create!(title: "CAM", row: 1, column: 1, width: width, height: height, position: position)
    tile.dashboard_widgets.create!(device_capability: capability, widget_type: "camera_feed", title: "CAM Feed", position: 1)
    tile
  end

  def stat_tile(width:, height:)
    position = @dashboard.dashboard_tiles.maximum(:position).to_i + 1
    @dashboard.dashboard_tiles.create!(title: "Stat", row: 1, column: 41, width: width, height: height, position: position)
  end
end
