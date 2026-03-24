require "test_helper"

class PolarClientTest < ActiveSupport::TestCase
  test "build_uri keeps api paths absolute" do
    client = PolarClient.new(
      base_url: "http://192.168.86.53:6702",
      token: "test-token"
    )

    uri = client.send(:build_uri, "/v1/climate/snapshot")

    assert_equal "http://192.168.86.53:6702/v1/climate/snapshot", uri.to_s
  end

  test "build_uri preserves configured base paths" do
    client = PolarClient.new(
      base_url: "http://192.168.86.53:6702/polar",
      token: "test-token"
    )

    uri = client.send(:build_uri, "/v1/station/health")

    assert_equal "http://192.168.86.53:6702/polar/v1/station/health", uri.to_s
  end
end
