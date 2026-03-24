require "test_helper"

class KoalaClientTest < ActiveSupport::TestCase
  test "build_uri keeps mcp paths absolute" do
    client = KoalaClient.new(
      base_url: "http://192.168.86.53:8082",
      token: "test-token"
    )

    uri = client.send(:build_uri, "/mcp/tools/koala.list_cameras", {})

    assert_equal "http://192.168.86.53:8082/mcp/tools/koala.list_cameras", uri.to_s
  end

  test "build_uri preserves configured base paths" do
    client = KoalaClient.new(
      base_url: "http://192.168.86.53:8082/koala",
      token: "test-token"
    )

    uri = client.send(:build_uri, "/admin/cameras/cam_1/snapshot", {})

    assert_equal "http://192.168.86.53:8082/koala/admin/cameras/cam_1/snapshot", uri.to_s
  end
end
