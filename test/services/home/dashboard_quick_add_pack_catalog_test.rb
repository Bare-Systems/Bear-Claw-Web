require "test_helper"
require "securerandom"

class Home::DashboardQuickAddPackCatalogTest < ActiveSupport::TestCase
  setup do
    token = SecureRandom.hex(6)
    @user = User.create!(
      email: "dashboard-pack-catalog-#{token}@example.com",
      google_uid: "dashboard-pack-catalog-#{token}",
      name: "Dashboard Pack Catalog #{token}",
      role: :operator
    )

    build_capabilities(token)
  end

  test "builds quick-add packs from available capabilities" do
    packs = Home::DashboardQuickAddPackCatalog.new(capabilities: DeviceCapability.all).available_packs

    assert_equal [ "air_quality_strip", "camera_wall", "portfolio_pulse", "security_pulse" ], packs.map(&:key).sort

    camera_pack = packs.find { |pack| pack.key == "camera_wall" }
    assert_equal 2, camera_pack.items.size
    assert_equal [ "camera_feed", "camera_feed" ], camera_pack.items.map(&:widget_type)

    portfolio_pack = packs.find { |pack| pack.key == "portfolio_pulse" }
    assert_equal [ "portfolio_stat" ], portfolio_pack.items.map(&:widget_type).uniq
  end

  private

  def build_capabilities(token)
    create_capability(token: token, provider_key: "koala", connection_key: "koala-#{token}", device_key: "cam-1-#{token}", device_name: "CAM 1", capability_key: "feed-1", capability_name: "CAM 1 Feed", capability_type: "camera_feed", configuration: { "camera_id" => "cam_1" })
    create_capability(token: token, provider_key: "koala", connection_key: "koala-#{token}", device_key: "cam-2-#{token}", device_name: "CAM 2", capability_key: "feed-2", capability_name: "CAM 2 Feed", capability_type: "camera_feed", configuration: { "camera_id" => "cam_2" })
    create_capability(token: token, provider_key: "polar", connection_key: "polar-#{token}", device_key: "sensor-1-#{token}", device_name: "Indoor Climate", capability_key: "co2", capability_name: "CO2", capability_type: "sensor", configuration: { "metric" => "co2" })
    create_capability(token: token, provider_key: "kodiak", connection_key: "kodiak-#{token}", device_key: "portfolio-#{token}", device_name: "Kodiak Portfolio", capability_key: "equity", capability_name: "Equity", capability_type: "finance", configuration: { "metric" => "equity" })
    create_capability(token: token, provider_key: "ursa", connection_key: "ursa-#{token}", device_key: "ursa-#{token}", device_name: "Ursa", capability_key: "sessions", capability_name: "Sessions", capability_type: "status", configuration: { "service" => "ursa" })
  end

  def create_capability(token:, provider_key:, connection_key:, device_key:, device_name:, capability_key:, capability_name:, capability_type:, configuration:)
    provider = ServiceProvider.find_or_create_by!(key: provider_key) do |record|
      record.name = provider_key.humanize
      record.provider_type = "network"
    end
    connection = ServiceConnection.find_or_create_by!(key: connection_key) do |record|
      record.service_provider = provider
      record.name = "#{provider.name} Main"
      record.adapter = provider_key
      record.credential_strategy = "environment"
      record.status = "online"
      record.base_url = "http://#{provider_key}.test"
    end
    device = Device.create!(
      service_connection: connection,
      user: @user,
      key: device_key,
      name: device_name,
      category: capability_type == "camera_feed" ? "camera" : "network_service",
      source_kind: "network",
      source_identifier: "#{device_key}-#{token}",
      status: "available"
    )
    DeviceCapability.create!(
      device: device,
      key: capability_key,
      name: capability_name,
      capability_type: capability_type,
      configuration: configuration,
      state: { "status" => "available" }
    )
  end
end
