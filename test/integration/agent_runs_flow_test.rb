require "test_helper"

class AgentRunsFlowTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @user.update!(role: :operator)
  end

  test "operator can log in, list runs, and open a run detail view" do
    fake_client = Object.new
    fake_client.define_singleton_method(:list_runs) do
      {
        "runs" => [
          {
            "id" => "run-456",
            "status" => "done",
            "started_at" => 1_710_000_000,
            "updated_at" => 1_710_000_005,
            "user_id" => "user-42",
            "device_id" => "bearclaw-web",
            "event_count" => 2
          }
        ]
      }
    end
    fake_client.define_singleton_method(:get_run) do |_id|
      {
        "run" => {
          "id" => "run-456",
          "status" => "done",
          "started_at" => 1_710_000_000,
          "updated_at" => 1_710_000_005,
          "user_id" => "user-42",
          "device_id" => "bearclaw-web",
          "event_count" => 2
        },
        "events" => [
          { "type" => "tool_call", "ts" => 1_710_000_001, "tool" => "koala__snapshot", "arguments" => "{\"camera\":\"front\"}" },
          { "type" => "done", "ts" => 1_710_000_005, "content" => "snapshot complete" }
        ]
      }
    end

    original_new = BearClawClient.method(:new)
    BearClawClient.define_singleton_method(:new) { |*| fake_client }

    begin
      get dev_login_path(email: @user.email)
      follow_redirect!
      assert_response :success

      get agent_runs_path
      assert_response :success
      assert_select "h1", text: "Runs"
      assert_select "td", text: /run-456/

      get agent_run_path("run-456")
    ensure
      BearClawClient.define_singleton_method(:new) { |*args, **kwargs, &block| original_new.call(*args, **kwargs, &block) }
    end

    assert_response :success
    assert_select "h1", text: "run-456"
    assert_select "span", text: "Tool Call"
    assert_select "span", text: "koala__snapshot"
  end
end
