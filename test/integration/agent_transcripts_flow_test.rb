require "test_helper"

class AgentTranscriptsFlowTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @user.update!(role: :operator)
  end

  test "operator can log in, browse transcripts, and open a transcript detail view" do
    fake_client = Object.new
    fake_client.define_singleton_method(:list_transcripts) do
      {
        "transcripts" => [
          {
            "id" => 3,
            "ts_ms" => 1_710_000_000,
            "scope" => "chat",
            "route" => "/v1/chat",
            "identity" => "user-42",
            "client_ip" => "127.0.0.1",
            "response_status" => 200
          }
        ]
      }
    end
    fake_client.define_singleton_method(:get_transcript) do |_id|
      {
        "transcript" => {
          "id" => 3,
          "ts_ms" => 1_710_000_000,
          "scope" => "chat",
          "route" => "/v1/chat",
          "correlation_id" => "corr-3",
          "identity" => "user-42",
          "client_ip" => "127.0.0.1",
          "upstream_url" => "http://127.0.0.1:6701/v1/chat",
          "request_body" => "{\"message\":\"hello\"}",
          "response_status" => 200,
          "response_content_type" => "application/json",
          "response_body" => "{\"ok\":true}"
        }
      }
    end

    original_new = BearClawClient.method(:new)
    BearClawClient.define_singleton_method(:new) { |*| fake_client }

    begin
      get dev_login_path(email: @user.email)
      follow_redirect!
      assert_response :success

      get agent_transcripts_path
      assert_response :success
      assert_select "h1", text: "Transcripts"
      assert_select "td", text: /\/v1\/chat/

      get agent_transcript_path(3)
    ensure
      BearClawClient.define_singleton_method(:new) { |*args, **kwargs, &block| original_new.call(*args, **kwargs, &block) }
    end

    assert_response :success
    assert_select "h1", text: "Transcript #3"
    assert_select "dt", text: "Upstream URL"
    assert_select "pre", text: /"ok": true/
  end
end
