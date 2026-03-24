require "test_helper"

class Security::EventsControllerTest < ActionController::TestCase
  tests Security::EventsController

  setup do
    @user = User.find_by!(email: users(:one)["email"])
    @user.update!(role: :admin)
    @request.session[:user_id] = @user.id
  end

  test "renders the events index when Ursa events are available" do
    requested_path = nil
    requested_params = nil
    fake_client = Object.new
    fake_client.define_singleton_method(:get_json) do |path, params: {}|
      requested_path = path
      requested_params = params

      {
        "events" => [
          {
            "level" => "warning",
            "source" => "ursa",
            "timestamp" => Time.current.iso8601,
            "message" => "Policy alert",
            "campaign" => "spring"
          }
        ]
      }
    end

    original_new = UrsaClient.method(:new)
    UrsaClient.define_singleton_method(:new) { |*| fake_client }

    begin
      get :index, params: { level: "warning" }
    ensure
      UrsaClient.define_singleton_method(:new) { |*args, **kwargs, &block| original_new.call(*args, **kwargs, &block) }
    end

    assert_response :success
    assert_equal "/api/v1/events", requested_path
    assert_equal({"level" => "warning"}, requested_params)
    assert_match security_events_path, @response.body
    assert_match "Policy alert", @response.body
  end
end
