require "test_helper"
require "securerandom"

class Home::DashboardResetterTest < ActiveSupport::TestCase
  setup do
    DashboardWidget.delete_all
    DashboardTile.delete_all
    Dashboard.delete_all
    DeviceCapability.delete_all
    Device.delete_all
    ServiceConnection.delete_all
    ServiceProvider.delete_all

    token = SecureRandom.hex(6)
    @user = User.create!(
      email: "dashboard-resetter-#{token}@example.com",
      google_uid: "dashboard-resetter-#{token}",
      name: "Dashboard Resetter #{token}",
      role: :operator
    )

    provider = ServiceProvider.create!(key: "koala", name: "Koala", provider_type: "hybrid")
    connection = ServiceConnection.create!(
      service_provider: provider,
      key: "koala-main-#{token}",
      name: "Koala Main",
      adapter: "koala",
      credential_strategy: "environment",
      status: "online",
      base_url: "http://koala.test"
    )

    (1..4).each do |index|
      device = Device.create!(
        service_connection: connection,
        user: @user,
        key: "reset-camera-#{index}",
        name: "CAM #{index}",
        category: "camera",
        source_kind: "physical",
        source_identifier: "cam_#{index}",
        status: "available"
      )
      DeviceCapability.create!(
        device: device,
        key: "primary_feed",
        name: "CAM #{index} Feed",
        capability_type: "camera_feed",
        configuration: { "camera_id" => "cam_#{index}" },
        state: { "status" => "available" }
      )
    end

    @dashboard = Home::DashboardProvisioner.new(user: @user).home_dashboard
    @dashboard = Home::DashboardDensityUpgrader.new(dashboard: @dashboard).upgrade!
  end

  test "restore_defaults rebuilds the seeded dashboard layout and records undo history" do
    @dashboard.dashboard_tiles.first.update!(title: "Mutated Camera", row: 5, column: 5, width: 4, height: 4, settings: { "section" => "Security" })
    @dashboard.dashboard_tiles.create!(title: "Scratch Pad", row: 7, column: 1, width: 2, height: 2, position: 99)

    resetter = Home::DashboardResetter.new(dashboard: @dashboard, user: @user)
    resetter.restore_defaults!

    @dashboard.reload

    assert_equal [ "CAM 1", "CAM 2", "CAM 3", "CAM 4" ], @dashboard.dashboard_tiles.order(:position).pluck(:title)
    assert_equal [ 1, 1, 2, 2 ], @dashboard.dashboard_tiles.order(:position).first.attributes.values_at("row", "column", "width", "height")
    assert_nil @dashboard.dashboard_tiles.order(:position).first.settings_hash["section"]

    history = Home::DashboardLayoutHistory.new(dashboard: @dashboard)
    assert_equal "Before restore defaults", history.entries.last.fetch("label")
    assert_equal [ "CAM 2", "CAM 3", "CAM 4", "Mutated Camera", "Scratch Pad" ].sort,
      history.entries.last.fetch("tiles").map { |tile| tile.fetch("title") }.sort
  end

  test "restore_defaults clears custom dashboards without a provisioned baseline" do
    custom_dashboard = Dashboard.fetch_or_create_for!(user: @user, context: :home, name: "Custom Board")
    custom_dashboard.update!(settings: custom_dashboard.settings_hash.merge("columns" => 8))
    custom_dashboard.dashboard_tiles.create!(title: "Scratch Pad", row: 1, column: 1, width: 2, height: 2, position: 1)

    Home::DashboardResetter.new(dashboard: custom_dashboard, user: @user).restore_defaults!

    assert_empty custom_dashboard.reload.dashboard_tiles
    assert_equal "Before restore defaults", Home::DashboardLayoutHistory.new(dashboard: custom_dashboard).entries.last.fetch("label")
  end
end
