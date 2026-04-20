require "test_helper"

class Agent::RunsControllerTest < ActionController::TestCase
  tests Agent::RunsController

  setup do
    @user = User.find_by!(email: users(:one)["email"])
    @user.update!(role: :operator)
    @request.session[:user_id] = @user.id
  end

  test "renders recent runs and show view with redacted payloads" do
    fake_client = Object.new
    fake_client.define_singleton_method(:list_runs) do
      {
        "runs" => [
          {
            "id" => "run-123",
            "status" => "done",
            "started_at" => 1_710_000_000,
            "updated_at" => 1_710_000_005,
            "user_id" => "user-42",
            "device_id" => "bearclaw-web",
            "event_count" => 3
          }
        ]
      }
    end
    fake_client.define_singleton_method(:get_run) do |_id|
      {
        "run" => {
          "id" => "run-123",
          "status" => "done",
          "started_at" => 1_710_000_000,
          "updated_at" => 1_710_000_005,
          "user_id" => "user-42",
          "device_id" => "bearclaw-web",
          "event_count" => 3
        },
        "events" => [
          { "type" => "prompt", "ts" => 1_710_000_000, "content" => "inspect the camera fleet" },
          { "type" => "tool_call", "ts" => 1_710_000_001, "tool" => "file_read", "arguments" => "{\"Authorization\":\"Bearer [REDACTED]\"}" },
          { "type" => "done", "ts" => 1_710_000_005, "content" => "all good" }
        ]
      }
    end

    original_new = BearClawClient.method(:new)
    BearClawClient.define_singleton_method(:new) { |*| fake_client }

    begin
      get :index
      assert_response :success
      assert_match "run-123", @response.body
      assert_match "user-42", @response.body

      get :show, params: { id: "run-123" }
    ensure
      BearClawClient.define_singleton_method(:new) { |*args, **kwargs, &block| original_new.call(*args, **kwargs, &block) }
    end

    assert_response :success
    assert_match "Tool Call", @response.body
    assert_match "file_read", @response.body
    assert_match "Bearer [REDACTED]", @response.body
    assert_no_match "token-123", @response.body
  end

  test "renders a stable unavailable state when BearClaw cannot be reached" do
    fake_client = Object.new
    fake_client.define_singleton_method(:list_runs) do
      raise BearClawClient::RequestError.new("BearClaw request failed: connection refused", status: 502, body: "")
    end

    original_new = BearClawClient.method(:new)
    BearClawClient.define_singleton_method(:new) { |*| fake_client }

    begin
      get :index
    ensure
      BearClawClient.define_singleton_method(:new) { |*args, **kwargs, &block| original_new.call(*args, **kwargs, &block) }
    end

    assert_response :success
    assert_match "BearClaw Unavailable", @response.body
    assert_match "connection refused", @response.body
  end
end
