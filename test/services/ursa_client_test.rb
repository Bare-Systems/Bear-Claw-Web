require "test_helper"

class UrsaClientTest < ActiveSupport::TestCase
  test "build_uri keeps api paths absolute" do
    client = UrsaClient.new(
      base_url: "http://192.168.86.53:6707",
      token: "test-token",
      actor: "test-actor"
    )

    uri = client.send(:build_uri, "/api/v1/overview", {})

    assert_equal "http://192.168.86.53:6707/api/v1/overview", uri.to_s
  end

  test "build_uri preserves configured base paths" do
    client = UrsaClient.new(
      base_url: "http://192.168.86.53:6707/ursa",
      token: "test-token",
      actor: "test-actor"
    )

    uri = client.send(:build_uri, "/api/v1/overview", {})

    assert_equal "http://192.168.86.53:6707/ursa/api/v1/overview", uri.to_s
  end
end
