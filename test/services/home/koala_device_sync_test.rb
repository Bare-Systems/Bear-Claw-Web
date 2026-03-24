require "test_helper"

class Home::KoalaDeviceSyncTest < ActiveSupport::TestCase
  test "syncs koala into providers, connections, devices, and capabilities" do
    fake_client = Object.new
    fake_client.define_singleton_method(:list_cameras) do
      {
        "data" => {
          "cameras" => [
            {
              "id" => "cam_1",
              "name" => "Front Door",
              "status" => "available",
              "zone_id" => "front_door",
              "capability" => {
                "selected_source" => "rtsp",
                "last_probed_at" => "2026-03-20T10:00:00Z"
              }
            }
          ]
        }
      }
    end

    Home::KoalaDeviceSync.new(
      client: fake_client,
      base_url: "http://192.168.86.53:8082"
    ).sync!

    provider = ServiceProvider.find_by!(key: "koala")
    connection = ServiceConnection.find_by!(key: "koala")
    dvr = Device.find_by!(key: "koala-dvr")
    camera = Device.find_by!(key: "koala-camera-cam_1")
    capability = DeviceCapability.find_by!(device: camera, key: "primary_feed")

    assert_equal "hybrid", provider.provider_type
    assert_equal provider, connection.service_provider
    assert_equal dvr, camera.parent_device
    assert_equal "camera_feed", capability.capability_type
    assert_equal "cam_1", capability.camera_id
    assert_equal 8, Device.where(category: "camera").count
    assert_equal 8, DeviceCapability.where(capability_type: "camera_feed").count
  end
end
