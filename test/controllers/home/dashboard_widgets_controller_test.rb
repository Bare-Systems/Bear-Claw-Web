require "test_helper"

class Home::DashboardWidgetsControllerTest < ActionController::TestCase
  tests Home::DashboardWidgetsController

  setup do
    @user = User.find_by!(email: users(:one)["email"])
    @user.update!(role: :operator)
    @request.session[:user_id] = @user.id

    provider = ServiceProvider.create!(key: "koala", name: "Koala", provider_type: "hybrid")
    connection = ServiceConnection.create!(
      service_provider: provider,
      key: "koala-main",
      name: "Koala Main",
      adapter: "koala",
      credential_strategy: "environment",
      status: "online",
      base_url: "http://192.168.86.53:8082"
    )
    device = Device.create!(
      service_connection: connection,
      key: "koala-camera-cam_1",
      name: "CAM 1",
      category: "camera",
      source_kind: "physical",
      source_identifier: "cam_1",
      status: "available"
    )
    @capability = DeviceCapability.create!(
      device: device,
      key: "primary_feed",
      name: "CAM 1 Feed",
      capability_type: "camera_feed",
      configuration: { "camera_id" => "cam_1" },
      state: { "status" => "available" }
    )
    @dashboard = Dashboard.fetch_or_create_for!(user: @user, context: :home, name: "Home Dashboard")
    @tile = @dashboard.dashboard_tiles.create!(title: "Custom Tile", row: 1, column: 1, width: 1, height: 1, position: 1)
  end

  test "creates a widget for a tile from a capability" do
    assert_difference("DashboardWidget.count", 1) do
      post :create, params: {
        dashboard_tile_id: @tile.id,
        dashboard_widget: {
          device_capability_id: @capability.id,
          title: "Front Door",
          refresh_interval_seconds: 6
        }
      }
    end

    widget = DashboardWidget.order(:id).last

    assert_redirected_to home_root_path(edit: 1)
    assert_equal "camera_feed", widget.widget_type
    assert_equal 6, widget.refresh_interval_seconds
  end
end
