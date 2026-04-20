require "test_helper"

class BearClawClientTest < ActiveSupport::TestCase
  test "build_uri preserves configured base paths" do
    client = BearClawClient.new(
      base_url: "https://bearclaw.baresystems.com/bearclaw",
      identity_token: "scoped-token"
    )

    uri = client.send(:build_uri, "/v1/chat")

    assert_equal "https://bearclaw.baresystems.com/bearclaw/v1/chat", uri.to_s
  end

  test "authorization token prefers scoped identity token over static token" do
    client = BearClawClient.new(
      base_url: "https://bearclaw.baresystems.com/bearclaw",
      token: "static-token",
      identity_token: "scoped-token"
    )

    assert_equal "scoped-token", client.send(:authorization_token)
  end

  test "normalize_run_id rejects unsafe path segments" do
    client = BearClawClient.new(base_url: "https://bearclaw.baresystems.com/bearclaw")

    assert_raises(BearClawClient::RequestError) do
      client.send(:normalize_run_id, "../run-1")
    end
  end

  test "normalize_numeric_id rejects unsafe transcript ids" do
    client = BearClawClient.new(base_url: "https://bearclaw.baresystems.com/bearclaw")

    assert_raises(BearClawClient::RequestError) do
      client.send(:normalize_numeric_id, "0", name: "transcript id")
    end

    assert_raises(BearClawClient::RequestError) do
      client.send(:normalize_numeric_id, "../1", name: "transcript id")
    end
  end
end
