require "test_helper"

class Home::UrsaDeviceSyncTest < ActiveSupport::TestCase
  setup do
    @user = User.find_by!(email: users(:one)["email"])
    @user.update!(role: :admin)
  end

  test "syncs session and campaign counts into device capabilities" do
    sync!(
      sessions:  [ { "id" => "s1", "status" => "active" }, { "id" => "s2", "status" => "inactive" } ],
      campaigns: [ { "id" => "c1", "status" => "active" }, { "id" => "c2", "status" => "closed" } ]
    )

    sessions_cap  = DeviceCapability.find_by!(key: "ursa_sessions")
    campaigns_cap = DeviceCapability.find_by!(key: "ursa_campaigns")

    assert_equal "status", sessions_cap.capability_type
    assert_equal 1, sessions_cap.state_hash["value"]
    assert_equal "sessions", sessions_cap.state_hash["unit"]
    assert_equal 1, sessions_cap.state_hash.dig("breakdown", "Active")
    assert_equal 2, sessions_cap.state_hash.dig("breakdown", "Total")

    assert_equal 1, campaigns_cap.state_hash["value"]
    assert_equal "campaigns", campaigns_cap.state_hash["unit"]
    assert_equal 1, campaigns_cap.state_hash.dig("breakdown", "Open")
    assert_equal 2, campaigns_cap.state_hash.dig("breakdown", "Total")
  end

  # Regression: Ursa /api/v1/campaigns returns names as bare strings, not hashes.
  # UrsaDeviceSync must not crash with TypeError (no implicit conversion of String into Integer).
  test "campaigns returned as strings (real Ursa API shape) does not crash" do
    sync!(
      sessions:  [],
      campaigns: [ "red-team-q2", "internal-audit", "patch-tuesday" ]
    )

    cap = DeviceCapability.find_by!(key: "ursa_campaigns")
    assert_equal 0, cap.state_hash["value"]   # no hash-typed entries = 0 open
    assert_equal 3, cap.state_hash.dig("breakdown", "Total")
    assert_equal 3, cap.state_hash.dig("breakdown", "Closed")
  end

  test "mixed sessions (some hashes, some strings) does not crash" do
    sync!(
      sessions:  [ { "id" => "s1", "status" => "active" }, "orphan-session-id" ],
      campaigns: []
    )

    cap = DeviceCapability.find_by!(key: "ursa_sessions")
    assert_equal 1, cap.state_hash["value"]
    assert_equal 2, cap.state_hash.dig("breakdown", "Total")
  end

  test "sets connection status to error and re-raises on client failure" do
    fake = Object.new
    fake.define_singleton_method(:get_json) { |*| raise UrsaClient::RequestError.new("timeout", status: 504, body: "") }

    assert_raises(UrsaClient::RequestError) do
      Home::UrsaDeviceSync.new(client: fake, base_url: "http://192.168.86.53:18080", user: @user).sync!
    end

    connection = ServiceConnection.find_by!(key: "ursa")
    assert_equal "error", connection.status
    assert_match "timeout", connection.last_error
  end

  test "creates provider, connection, and device on first run" do
    sync!(sessions: [], campaigns: [])

    assert ServiceProvider.exists?(key: "ursa")
    assert ServiceConnection.exists?(key: "ursa")
    assert Device.exists?(key: "ursa-overview")
  end

  private

  def sync!(sessions:, campaigns:)
    fake = Object.new
    fake.define_singleton_method(:get_json) do |path, **|
      path.include?("campaigns") ? { "campaigns" => campaigns } : { "sessions" => sessions }
    end

    Home::UrsaDeviceSync.new(
      client:   fake,
      base_url: "http://192.168.86.53:18080",
      user:     @user
    ).sync!
  end
end
