require "test_helper"
require "securerandom"

class Home::DashboardTilesControllerTest < ActionController::TestCase
  tests Home::DashboardTilesController

  setup do
    token = SecureRandom.hex(6)
    @user = User.create!(
      email: "dashboard-tiles-#{token}@example.com",
      google_uid: "dashboard-tiles-#{token}",
      name: "Dashboard Tiles #{token}",
      role: :operator
    )
    @request.session[:user_id] = @user.id
    @dashboard = Dashboard.fetch_or_create_for!(user: @user, context: :home, name: "Home Dashboard")
    @dashboard.update!(settings: @dashboard.settings_hash.merge("columns" => 8))
  end

  test "creates a custom tile" do
    assert_difference("DashboardTile.count", 1) do
      post :create, params: {
        dashboard_tile: {
          title: "Climate",
          section: "Operations",
          row: 3,
          column: 1,
          width: 2,
          height: 1
        }
      }
    end

    tile = DashboardTile.order(:id).last

    assert_redirected_to home_root_path(edit: 1)
    assert_equal "Climate", tile.title
    assert_equal "Operations", tile.settings_hash["section"]
    assert_equal 2, tile.width
  end

  test "updates tile layout over json and returns normalized positions" do
    first = @dashboard.dashboard_tiles.create!(title: "First", row: 1, column: 1, width: 1, height: 1, position: 1)
    second = @dashboard.dashboard_tiles.create!(title: "Second", row: 1, column: 2, width: 1, height: 1, position: 2)

    patch :update, params: {
      id: first.id,
      dashboard_tile: {
        row: 1,
        column: 2,
        width: 1,
        height: 1
      },
      format: :json
    }

    assert_response :success

    payload = JSON.parse(@response.body)
    updated_first = payload.fetch("tiles").find { |tile| tile.fetch("id") == first.id }
    updated_second = payload.fetch("tiles").find { |tile| tile.fetch("id") == second.id }

    assert_equal 2, updated_first.fetch("column")
    assert_equal 1, updated_second.fetch("column")
  end

  test "updates tile layout with wider and taller dimensions on the dense grid" do
    tile = @dashboard.dashboard_tiles.create!(title: "Wide", row: 1, column: 1, width: 2, height: 2, position: 1)

    patch :update, params: {
      id: tile.id,
      dashboard_tile: {
        row: 1,
        column: 3,
        width: 6,
        height: 4
      },
      format: :json
    }

    assert_response :success

    tile.reload

    assert_equal 3, tile.column
    assert_equal 6, tile.width
    assert_equal 4, tile.height
  end

  test "updates a tile section" do
    tile = @dashboard.dashboard_tiles.create!(title: "Scoped", row: 1, column: 1, width: 2, height: 2, position: 1)

    patch :update, params: {
      id: tile.id,
      dashboard_tile: {
        title: "Scoped",
        section: "Security",
        row: 1,
        column: 1,
        width: 2,
        height: 2
      }
    }

    assert_redirected_to home_root_path(edit: 1)
    assert_equal "Security", tile.reload.settings_hash["section"]
  end

  test "applies a quick-add pack and creates recommended tiles with widgets" do
    provider = ServiceProvider.create!(key: "koala", name: "Koala", provider_type: "hybrid")
    connection = ServiceConnection.create!(
      service_provider: provider,
      key: "koala-pack-test",
      name: "Koala Main",
      adapter: "koala",
      credential_strategy: "environment",
      status: "online",
      base_url: "http://koala.test"
    )

    2.times do |index|
      device = Device.create!(
        service_connection: connection,
        user: @user,
        key: "pack-camera-#{index}",
        name: "CAM #{index + 1}",
        category: "camera",
        source_kind: "physical",
        source_identifier: "cam_#{index + 1}",
        status: "available"
      )
      DeviceCapability.create!(
        device: device,
        key: "primary_feed_#{index}",
        name: "CAM #{index + 1} Feed",
        capability_type: "camera_feed",
        configuration: { "camera_id" => "cam_#{index + 1}" },
        state: { "status" => "available" }
      )
    end

    assert_difference("DashboardTile.count", 2) do
      assert_difference("DashboardWidget.count", 2) do
        post :apply_pack, params: { dashboard_id: @dashboard.id, pack_key: "camera_wall" }
      end
    end

    assert_redirected_to home_root_path(edit: 1, dashboard: @dashboard.name)
    assert_equal [ "camera_feed" ], @dashboard.reload.dashboard_widgets.pluck(:widget_type).uniq
  end

  test "reapplying the same quick-add pack does not duplicate existing widgets" do
    provider = ServiceProvider.create!(key: "koala", name: "Koala", provider_type: "hybrid")
    connection = ServiceConnection.create!(
      service_provider: provider,
      key: "koala-pack-repeat-test",
      name: "Koala Main",
      adapter: "koala",
      credential_strategy: "environment",
      status: "online",
      base_url: "http://koala-repeat.test"
    )
    device = Device.create!(
      service_connection: connection,
      user: @user,
      key: "pack-camera-repeat",
      name: "CAM Repeat",
      category: "camera",
      source_kind: "physical",
      source_identifier: "cam_repeat",
      status: "available"
    )
    DeviceCapability.create!(
      device: device,
      key: "primary_feed_repeat",
      name: "CAM Repeat Feed",
      capability_type: "camera_feed",
      configuration: { "camera_id" => "cam_repeat" },
      state: { "status" => "available" }
    )

    post :apply_pack, params: { dashboard_id: @dashboard.id, pack_key: "camera_wall" }

    assert_no_difference("DashboardTile.count") do
      assert_no_difference("DashboardWidget.count") do
        post :apply_pack, params: { dashboard_id: @dashboard.id, pack_key: "camera_wall" }
      end
    end

    assert_redirected_to home_root_path(edit: 1, dashboard: @dashboard.name)
    assert_match "already applied", flash[:alert]
  end
end
