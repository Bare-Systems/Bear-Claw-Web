require "test_helper"

class Agent::DashboardControllerTest < ActionController::TestCase
  tests Agent::DashboardController

  setup do
    @user = User.find_by!(email: users(:one)["email"])
    @user.update!(role: :operator)
    @request.session[:user_id] = @user.id
  end

  test "renders the floating chat launcher on the dashboard" do
    get :index

    assert_response :success
    assert_match "Open BearClaw chat", @response.body
    assert_match "bearclaw-chat-panel", @response.body
  end
end
