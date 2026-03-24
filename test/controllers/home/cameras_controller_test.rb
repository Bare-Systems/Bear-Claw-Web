require "test_helper"

class Home::CamerasControllerTest < ActionController::TestCase
  tests Home::CamerasController

  setup do
    @user = User.find_by!(email: users(:one)["email"])
    @user.update!(role: :operator)
    @request.session[:user_id] = @user.id
  end

  test "proxies snapshots from koala" do
    requested_camera_id = nil
    fake_client = Object.new
    fake_client.define_singleton_method(:snapshot) do |camera_id|
      requested_camera_id = camera_id
      KoalaClient::Download.new(body: "jpeg-bytes", content_type: "image/jpeg", headers: {})
    end

    original_new = KoalaClient.method(:new)
    KoalaClient.define_singleton_method(:new) { |*| fake_client }

    begin
      get :snapshot, params: { id: "cam_1" }
    ensure
      KoalaClient.define_singleton_method(:new) { |*args, **kwargs, &block| original_new.call(*args, **kwargs, &block) }
    end

    assert_response :success
    assert_equal "cam_1", requested_camera_id
    assert_equal "image/jpeg", @response.media_type
    assert_equal "jpeg-bytes", @response.body
  end
end
