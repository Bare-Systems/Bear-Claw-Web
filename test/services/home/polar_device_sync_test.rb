require "test_helper"

class Home::PolarDeviceSyncTest < ActiveSupport::TestCase
  setup do
    @user = User.find_by!(email: users(:one)["email"])
  end

  test "syncs polar readings into providers, connections, devices, and capabilities" do
    fake_client = Object.new
    fake_client.define_singleton_method(:latest_readings) do
      [
        { "sensor_id" => "indoor", "source" => "airthings", "metric" => "temperature",
          "value" => 68.4, "unit" => "F", "quality_flag" => "good",
          "recorded_at" => "2026-03-20T14:58:00Z" },
        { "sensor_id" => "indoor", "source" => "airthings", "metric" => "humidity",
          "value" => 44.0, "unit" => "%", "quality_flag" => "good",
          "recorded_at" => "2026-03-20T14:58:00Z" },
        { "sensor_id" => "outdoor", "source" => "open_meteo", "metric" => "temperature",
          "value" => 41.0, "unit" => "F", "quality_flag" => "estimated",
          "recorded_at" => "2026-03-20T14:55:00Z" }
      ]
    end
    fake_client.define_singleton_method(:station_health) do
      { "station_id" => "homelab", "overall" => "healthy",
        "generated_at" => "2026-03-20T15:00:00Z",
        "components" => [ { "name" => "collector", "status" => "ok" } ] }
    end

    Home::PolarDeviceSync.new(
      client:   fake_client,
      base_url: "http://192.168.86.53:6702",
      user:     @user
    ).sync!

    provider    = ServiceProvider.find_by!(key: "polar")
    connection  = ServiceConnection.find_by!(key: "polar")
    station     = Device.find_by!(key: "polar-station-homelab")
    indoor      = Device.find_by!(key: "polar-homelab-indoor")
    outdoor     = Device.find_by!(key: "polar-homelab-outdoor")
    station_cap = DeviceCapability.find_by!(device: station, key: "station_health")
    temp_cap    = DeviceCapability.find_by!(device: indoor,  key: "metric_temperature")
    hum_cap     = DeviceCapability.find_by!(device: indoor,  key: "metric_humidity")

    assert_equal "network",   provider.provider_type
    assert_equal provider,    connection.service_provider
    assert_equal "online",    connection.status
    assert_equal station,     indoor.parent_device
    assert_equal station,     outdoor.parent_device
    assert_equal "status",    station_cap.capability_type
    assert_equal "sensor",    temp_cap.capability_type
    assert_equal 68.4,        temp_cap.state_hash["value"]
    assert_equal "F",         temp_cap.state_hash["unit"]
    assert_equal "sensor",    hum_cap.capability_type
    assert_equal 44.0,        hum_cap.state_hash["value"]
    assert_equal 2, DeviceCapability.where(device: indoor).count
    assert_equal 1, DeviceCapability.where(device: outdoor).count
  end

  test "connection status set to error and re-raises on client failure" do
    fake = Object.new
    fake.define_singleton_method(:latest_readings) { raise PolarClient::RequestError.new("timeout", status: 504, body: "") }
    fake.define_singleton_method(:station_health) { {} }

    assert_raises(PolarClient::RequestError) do
      Home::PolarDeviceSync.new(client: fake, base_url: "http://192.168.86.53:6702", user: @user).sync!
    end

    assert_equal "error", ServiceConnection.find_by!(key: "polar").status
  end

  test "sync is idempotent" do
    fake = make_fake_client
    Home::PolarDeviceSync.new(client: fake, base_url: "http://192.168.86.53:6702", user: @user).sync!
    Home::PolarDeviceSync.new(client: fake, base_url: "http://192.168.86.53:6702", user: @user).sync!

    assert_equal 1, ServiceProvider.where(key: "polar").count
    assert_equal 1, ServiceConnection.where(key: "polar").count
  end

  private

  def make_fake_client
    fake = Object.new
    fake.define_singleton_method(:latest_readings) do
      [ { "sensor_id" => "indoor", "source" => "airthings", "metric" => "temperature",
          "value" => 68.0, "unit" => "F", "quality_flag" => "good",
          "recorded_at" => "2026-03-20T14:58:00Z" } ]
    end
    fake.define_singleton_method(:station_health) do
      { "station_id" => "homelab", "overall" => "ok",
        "generated_at" => "2026-03-20T15:00:00Z", "components" => [] }
    end
    fake
  end
end
