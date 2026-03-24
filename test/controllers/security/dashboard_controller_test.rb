require "test_helper"

class Security::DashboardControllerTest < ActionController::TestCase
  tests Security::DashboardController

  setup do
    @user = User.find_by!(email: users(:one)["email"])
    @user.update!(role: :admin)
    @request.session[:user_id] = @user.id
  end

  test "renders the dashboard when Ursa overview is available" do
    requested_path = nil
    fake_client = Object.new
    fake_client.define_singleton_method(:get_json) do |path, **|
      requested_path = path

      {
        "active_count" => 1,
        "pending_approvals" => 0,
        "policy_alert_count" => 0,
        "total_sessions" => 1,
        "recent_tasks" => [],
        "recent_events" => []
      }
    end

    original_new = UrsaClient.method(:new)
    UrsaClient.define_singleton_method(:new) { |*| fake_client }

    begin
      get :index
    ensure
      UrsaClient.define_singleton_method(:new) { |*args, **kwargs, &block| original_new.call(*args, **kwargs, &block) }
    end

    assert_response :success
    assert_equal "/api/v1/overview", requested_path
    assert_match security_events_path, @response.body
  end

  test "renders an unavailable page instead of redirecting on Ursa failure" do
    fake_client = Object.new
    fake_client.define_singleton_method(:get_json) do |*|
      raise UrsaClient::RequestError.new("Ursa offline", status: 502, body: "")
    end

    original_new = UrsaClient.method(:new)
    UrsaClient.define_singleton_method(:new) { |*| fake_client }

    begin
      get :index
    ensure
      UrsaClient.define_singleton_method(:new) { |*args, **kwargs, &block| original_new.call(*args, **kwargs, &block) }
    end

    assert_response :service_unavailable
    assert_match "Ursa is currently unavailable", @response.body
    assert_match "Ursa offline", @response.body
  end
end
