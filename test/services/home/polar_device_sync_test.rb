require "test_helper"

class Home::PolarDeviceSyncTest < ActiveSupport::TestCase
  test "syncs polar climate snapshot into providers, connections, devices, and capabilities" do
    fake_client = Object.new
    fake_client.define_singleton_method(:climate_snapshot) do
      {
        "station_id" => "homelab",
        "generated_at" => "2026-03-20T15:00:00Z",
        "indoor" => {
          "sources" => [ "airthings" ],
          "readings" => [
            {
              "name" => "temperature",
              "display_name" => "Temperature",
              "value" => 68.4,
              "unit" => "F",
              "display_value" => "68.4 F",
              "domain" => "thermal",
              "source" => "airthings",
              "quality" => "good",
              "recorded_at" => "2026-03-20T14:58:00Z"
            },
            {
              "name" => "humidity",
              "display_name" => "Humidity",
              "value" => 44.0,
              "unit" => "%",
              "display_value" => "44 %",
              "domain" => "comfort",
              "source" => "airthings",
              "quality" => "good",
              "recorded_at" => "2026-03-20T14:58:00Z"
            }
          ],
          "last_reading_at" => "2026-03-20T14:58:00Z",
          "stale" => false
        },
        "outdoor" => {
          "sources" => [ "open_meteo" ],
          "current" => [
            {
              "name" => "temperature",
              "display_name" => "Outdoor Temperature",
              "value" => 41.0,
              "unit" => "F",
              "display_value" => "41 F",
              "domain" => "weather",
              "source" => "open_meteo",
              "quality" => "estimated",
              "recorded_at" => "2026-03-20T14:55:00Z"
            }
          ],
          "last_fetched_at" => "2026-03-20T14:55:00Z",
          "fresh_until" => "2026-03-20T15:25:00Z",
          "stale" => false
        }
      }
    end
    fake_client.define_singleton_method(:station_health) do
      {
        "station_id" => "homelab",
        "overall" => "healthy",
        "generated_at" => "2026-03-20T15:00:00Z",
        "components" => [
          { "name" => "collector", "status" => "ok", "message" => "sensor sampling" }
        ]
      }
    end

    Home::PolarDeviceSync.new(
      client: fake_client,
      base_url: "http://192.168.86.53:6702"
    ).sync!

    provider = ServiceProvider.find_by!(key: "polar")
    connection = ServiceConnection.find_by!(key: "polar")
    station = Device.find_by!(key: "polar-station-homelab")
    indoor = Device.find_by!(key: "polar-homelab-indoor")
    outdoor = Device.find_by!(key: "polar-homelab-outdoor")
    station_capability = DeviceCapability.find_by!(device: station, key: "station_health")
    temp_capability = DeviceCapability.find_by!(device: indoor, key: "metric_temperature")
    humidity_capability = DeviceCapability.find_by!(device: indoor, key: "metric_humidity")

    assert_equal "network", provider.provider_type
    assert_equal provider, connection.service_provider
    assert_equal "online", connection.status
    assert_equal station, indoor.parent_device
    assert_equal station, outdoor.parent_device
    assert_equal "status", station_capability.capability_type
    assert_equal "sensor", temp_capability.capability_type
    assert_equal "68.4 F", temp_capability.state_hash["display_value"]
    assert_equal 3, DeviceCapability.where(device: [ indoor, outdoor ]).count
    assert_equal "44 %", humidity_capability.state_hash["display_value"]
  end
end
