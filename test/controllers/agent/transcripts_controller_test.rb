require "test_helper"

class Agent::TranscriptsControllerTest < ActionController::TestCase
  tests Agent::TranscriptsController

  setup do
    @user = User.find_by!(email: users(:one)["email"])
    @user.update!(role: :operator)
    @request.session[:user_id] = @user.id
  end

  test "renders transcript list and detail with redacted payloads" do
    fake_client = Object.new
    fake_client.define_singleton_method(:list_transcripts) do
      {
        "transcripts" => [
          {
            "id" => 7,
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
          "id" => 7,
          "ts_ms" => 1_710_000_000,
          "scope" => "chat",
          "route" => "/v1/chat",
          "correlation_id" => "corr-7",
          "identity" => "user-42",
          "client_ip" => "127.0.0.1",
          "upstream_url" => "http://127.0.0.1:6701/v1/chat",
          "request_body" => "{\"Authorization\":\"Bearer [REDACTED]\"}",
          "response_status" => 200,
          "response_content_type" => "application/json",
          "response_body" => "{\"token\":\"[REDACTED]\"}"
        }
      }
    end

    original_new = BearClawClient.method(:new)
    BearClawClient.define_singleton_method(:new) { |*| fake_client }

    begin
      get :index
      assert_response :success
      assert_match "Transcripts", @response.body
      assert_match "#7", @response.body

      get :show, params: { id: "7" }
    ensure
      BearClawClient.define_singleton_method(:new) { |*args, **kwargs, &block| original_new.call(*args, **kwargs, &block) }
    end

    assert_response :success
    assert_match "Transcript #7", @response.body
    assert_match "Bearer [REDACTED]", @response.body
    assert_no_match "opaque-secret", @response.body
  end

  test "renders a stable unavailable state when transcripts cannot be reached" do
    fake_client = Object.new
    fake_client.define_singleton_method(:list_transcripts) do
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
    assert_match "Tardigrade Unavailable", @response.body
    assert_match "connection refused", @response.body
  end
end
