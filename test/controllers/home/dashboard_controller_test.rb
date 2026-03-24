require "test_helper"

class Home::DashboardControllerTest < ActionController::TestCase
  tests Home::DashboardController

  setup do
    @user = User.find_by!(email: users(:one)["email"])
    @user.update!(role: :operator)
    @request.session[:user_id] = @user.id
  end

  test "renders the modular home dashboard with seeded camera widgets" do
    fake_client = Object.new
    fake_client.define_singleton_method(:list_cameras) do
      {
        "data" => {
          "cameras" => [
            { "id" => "cam_1", "name" => "CAM 1", "status" => "available", "zone_id" => "front_door", "capability" => { "selected_source" => "rtsp" } },
            { "id" => "cam_2", "name" => "CAM 2", "status" => "available", "zone_id" => "front_door", "capability" => { "selected_source" => "rtsp" } },
            { "id" => "cam_3", "name" => "CAM 3", "status" => "available", "zone_id" => "front_door", "capability" => { "selected_source" => "rtsp" } },
            { "id" => "cam_4", "name" => "CAM 4", "status" => "available", "zone_id" => "front_door", "capability" => { "selected_source" => "rtsp" } },
            { "id" => "cam_5", "name" => "CAM 5", "status" => "available", "zone_id" => "front_door", "capability" => { "selected_source" => "rtsp" } }
          ]
        }
      }
    end

    original_new = KoalaClient.method(:new)
    KoalaClient.define_singleton_method(:new) { |*| fake_client }

    begin
      get :index
    ensure
      KoalaClient.define_singleton_method(:new) { |*args, **kwargs, &block| original_new.call(*args, **kwargs, &block) }
    end

    assert_response :success
    assert_match "Home Dashboard", @response.body
    assert_match "Dashboard Layout", @response.body
    assert_match "CAM 1", @response.body
    assert_match "CAM 8", @response.body
    assert_match snapshot_home_camera_path("cam_1"), @response.body
    assert_equal 1, ServiceProvider.count
    assert_equal 1, ServiceConnection.count
    assert_equal 8, DashboardTile.count
    assert_equal 8, DashboardWidget.count
  end

  test "edit mode renders the dashboard editor" do
    fake_client = Object.new
    fake_client.define_singleton_method(:list_cameras) do
      { "data" => { "cameras" => [] } }
    end

    original_new = KoalaClient.method(:new)
    KoalaClient.define_singleton_method(:new) { |*| fake_client }

    begin
      get :index, params: { edit: 1 }
    ensure
      KoalaClient.define_singleton_method(:new) { |*args, **kwargs, &block| original_new.call(*args, **kwargs, &block) }
    end

    assert_response :success
    assert_match "Add Tile", @response.body
    assert_match "Add Widget", @response.body
    assert_match "Service Providers", @response.body
    assert_match "Devices and Capabilities", @response.body
    assert_match "data-controller=\"dashboard-layout\"", @response.body
    assert_match "Drag a tile header to move it", @response.body
  end
end
