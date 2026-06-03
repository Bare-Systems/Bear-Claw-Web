require "test_helper"

class Security::NetworkControllerTest < ActionController::TestCase
  tests Security::NetworkController

  setup do
    @user = User.find_by!(email: users(:one)["email"])
    @user.update!(role: :admin)
    @request.session[:user_id] = @user.id
  end

  def with_fake_client(fake_client)
    original_new = UrsaClient.method(:new)
    UrsaClient.define_singleton_method(:new) { |*| fake_client }
    begin
      yield
    ensure
      UrsaClient.define_singleton_method(:new) { |*args, **kwargs, &block| original_new.call(*args, **kwargs, &block) }
    end
  end

  test "renders the network inventory with counts, devices, and DNS talkers" do
    requested_paths = []
    fake_client = Object.new
    fake_client.define_singleton_method(:get_json) do |path, params: {}|
      requested_paths << path
      if path.include?("dns")
        {
          "overview" => { "available" => true, "total" => 1200, "blocked" => 300, "block_ratio" => 0.25 },
          "talkers" => [
            { "client" => "192.168.86.20", "total" => 800, "blocked" => 240, "block_ratio" => 0.3 }
          ]
        }
      else
        {
          "counts" => { "total" => 3, "trusted" => 2, "untrusted" => 1 },
          "devices" => [
            { "mac" => "aa:bb:cc:dd:ee:ff", "ip" => "192.168.86.20", "vendor" => "Apple", "label" => "Joe's iPhone", "trusted" => true, "last_seen" => Time.current.iso8601, "times_seen" => 9 },
            { "mac" => "11:22:33:44:55:66", "ip" => "192.168.86.99", "vendor" => "Unknown", "label" => nil, "trusted" => false, "last_seen" => Time.current.iso8601, "times_seen" => 1 }
          ]
        }
      end
    end

    with_fake_client(fake_client) { get :index }

    assert_response :success
    assert_includes requested_paths, "/api/v1/network/devices"
    assert_includes requested_paths, "/api/v1/dns/talkers"
    assert_match "Network Devices", @response.body
    assert_match "aa:bb:cc:dd:ee:ff", @response.body
    assert_match "Joe&#39;s iPhone", @response.body
    assert_match "unknown", @response.body
    assert_match "DNS Talkers", @response.body
    assert_match "192.168.86.20", @response.body
  end

  test "DNS insight unavailable does not blank the device inventory" do
    fake_client = Object.new
    fake_client.define_singleton_method(:get_json) do |path, params: {}|
      raise UrsaClient::RequestError.new("Not Found", status: 404, body: "") if path.include?("dns")
      { "counts" => { "total" => 1, "trusted" => 1, "untrusted" => 0 },
        "devices" => [ { "mac" => "aa:bb:cc:dd:ee:ff", "ip" => "192.168.86.20", "vendor" => "Apple", "trusted" => true, "last_seen" => Time.current.iso8601, "times_seen" => 2 } ] }
    end

    with_fake_client(fake_client) { get :index }

    assert_response :success
    assert_match "aa:bb:cc:dd:ee:ff", @response.body
    assert_match "DNS insight unavailable", @response.body
  end

  test "set baseline posts to ursa and redirects with notice" do
    posted_path = nil
    fake_client = Object.new
    fake_client.define_singleton_method(:post_json) do |path, payload: {}|
      posted_path = path
      { "trusted" => 5 }
    end

    with_fake_client(fake_client) { post :baseline }

    assert_redirected_to security_network_path
    assert_equal "/api/v1/network/baseline", posted_path
    assert_match "5 device", flash[:notice]
  end

  test "update_device patches trust state and forwards the mac" do
    patched_path = nil
    patched_payload = nil
    fake_client = Object.new
    fake_client.define_singleton_method(:patch_json) do |path, payload: {}|
      patched_path = path
      patched_payload = payload
      {}
    end

    with_fake_client(fake_client) { patch :update_device, params: { mac: "aa:bb:cc:dd:ee:ff", trusted: "true" } }

    assert_redirected_to security_network_path
    assert_equal "/api/v1/network/devices/aa:bb:cc:dd:ee:ff", patched_path
    assert_equal true, patched_payload[:trusted]
  end

  test "update_device forwards a label edit" do
    patched_payload = nil
    fake_client = Object.new
    fake_client.define_singleton_method(:patch_json) do |path, payload: {}|
      patched_payload = payload
      {}
    end

    with_fake_client(fake_client) do
      patch :update_device, params: { mac: "aa:bb:cc:dd:ee:ff", trusted: "true", label: "Living Room TV" }
    end

    assert_redirected_to security_network_path
    assert_equal "Living Room TV", patched_payload[:label]
    assert_equal true, patched_payload[:trusted]
  end

  test "non-admin users are blocked" do
    @user.update!(role: :operator)
    get :index
    assert_response :redirect
  end
end
