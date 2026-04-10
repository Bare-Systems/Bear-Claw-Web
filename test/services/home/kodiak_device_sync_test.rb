require "test_helper"

class Home::KodiakDeviceSyncTest < ActiveSupport::TestCase
  setup do
    @user = User.find_by!(email: users(:one)["email"])
    @user.update!(role: :admin)
  end

  test "syncs engine status into a status capability" do
    sync!(
      engine:    { "running" => true, "mode" => "paper", "dry_run" => false, "strategy_count" => 3 },
      portfolio: { "equity" => 100_000.0, "cash" => 25_000.0 }
    )

    cap = DeviceCapability.find_by!(key: "engine_status")
    assert_equal "status", cap.capability_type
    assert_equal "running", cap.state_hash["status"]
    assert_equal "paper",   cap.state_hash["mode"]
    assert_equal 3,         cap.state_hash["strategy_count"]
  end

  test "stopped engine maps to stopped status and degraded device status" do
    sync!(engine: { "running" => false }, portfolio: {})

    cap    = DeviceCapability.find_by!(key: "engine_status")
    device = Device.find_by!(key: "kodiak-engine")

    assert_equal "stopped",  cap.state_hash["status"]
    assert_equal "degraded", device.status
  end

  test "syncs portfolio metrics as finance capabilities" do
    sync!(
      engine: { "running" => true },
      portfolio: {
        "equity"       => 123_456.78,
        "cash"         => 10_000.0,
        "buying_power" => 20_000.0,
        "day_pnl"      => -500.25,
        "unrealized_pl" => 1_500.0
      }
    )

    equity = DeviceCapability.find_by!(key: "portfolio_equity")
    pnl    = DeviceCapability.find_by!(key: "portfolio_day_pnl")

    assert_equal "finance",  equity.capability_type
    assert_equal 123_456.78, equity.state_hash["value"]
    assert_equal "USD",      equity.state_hash["unit"]
    assert_equal -500.25,    pnl.state_hash["value"]

    assert_equal 5, DeviceCapability.where(capability_type: "finance").count
  end

  test "missing portfolio fields are skipped gracefully" do
    sync!(engine: { "running" => true }, portfolio: { "equity" => 50_000.0 })

    assert DeviceCapability.exists?(key: "portfolio_equity")
    assert_not DeviceCapability.exists?(key: "portfolio_cash")
  end

  test "sets connection status to error and re-raises on client failure" do
    fake = Object.new
    fake.define_singleton_method(:engine_status) { raise KodiakClient::RequestError.new("unreachable", status: 503, body: "") }
    fake.define_singleton_method(:portfolio_summary) { {} }

    assert_raises(KodiakClient::RequestError) do
      Home::KodiakDeviceSync.new(client: fake, base_url: "http://192.168.86.53:6702", user: @user).sync!
    end

    connection = ServiceConnection.find_by!(key: "kodiak")
    assert_equal "error", connection.status
    assert_match "unreachable", connection.last_error
  end

  test "creates provider, connection, and devices on first run" do
    sync!(engine: { "running" => true }, portfolio: {})

    assert ServiceProvider.exists?(key: "kodiak")
    assert ServiceConnection.exists?(key: "kodiak")
    assert Device.exists?(key: "kodiak-engine")
    assert Device.exists?(key: "kodiak-portfolio")
  end

  test "sync is idempotent — running twice does not duplicate records" do
    payload = { engine: { "running" => true }, portfolio: { "equity" => 1.0 } }
    sync!(**payload)
    sync!(**payload)

    assert_equal 1, ServiceProvider.where(key: "kodiak").count
    assert_equal 1, Device.where(key: "kodiak-engine").count
    assert_equal 1, DeviceCapability.where(key: "portfolio_equity").count
  end

  private

  def sync!(engine:, portfolio:)
    fake = Object.new
    fake.define_singleton_method(:engine_status)    { engine }
    fake.define_singleton_method(:portfolio_summary) { portfolio }

    Home::KodiakDeviceSync.new(
      client:   fake,
      base_url: "http://192.168.86.53:6702",
      user:     @user
    ).sync!
  end
end
