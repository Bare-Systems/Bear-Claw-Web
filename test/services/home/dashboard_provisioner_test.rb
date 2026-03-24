require "test_helper"

class Home::DashboardProvisionerTest < ActiveSupport::TestCase
  setup do
    @user = User.find_by!(email: users(:one)["email"])
    @user.update!(role: :operator)

    provider = ServiceProvider.create!(key: "koala", name: "Koala", provider_type: "hybrid")
    connection = ServiceConnection.create!(
      service_provider: provider,
      key: "koala-main",
      name: "Koala Main",
      adapter: "koala",
      credential_strategy: "environment",
      status: "online",
      base_url: "http://192.168.86.53:8082"
    )

    (1..8).each do |index|
      device = Device.create!(
        service_connection: connection,
        key: "koala-camera-cam_#{index}",
        name: "CAM #{index}",
        category: "camera",
        source_kind: "physical",
        source_identifier: "cam_#{index}",
        status: "available"
      )
      DeviceCapability.create!(
        device: device,
        key: "primary_feed",
        name: "CAM #{index} Feed",
        capability_type: "camera_feed",
        configuration: { "camera_id" => "cam_#{index}" },
        state: { "status" => "available" }
      )
    end
  end

  test "seeds a default home dashboard once" do
    provisioner = Home::DashboardProvisioner.new(user: @user)

    dashboard = provisioner.home_dashboard
    provisioner.home_dashboard

    assert_equal "Home Dashboard", dashboard.name
    assert_equal 8, dashboard.dashboard_tiles.count
    assert_equal 8, DashboardWidget.count
    assert_equal 1, Dashboard.count
  end

  test "adds default polar tiles when the dashboard is still on the untouched camera layout" do
    provider = ServiceProvider.create!(key: "polar", name: "Polar", provider_type: "network")
    connection = ServiceConnection.create!(
      service_provider: provider,
      key: "polar-main",
      name: "Polar Main",
      adapter: "polar",
      credential_strategy: "environment",
      status: "online",
      base_url: "http://192.168.86.53:6702"
    )
    device = Device.create!(
      service_connection: connection,
      key: "polar-homelab-indoor",
      name: "Indoor Climate",
      category: "sensor",
      source_kind: "network",
      source_identifier: "homelab:indoor",
      status: "available"
    )
    %w[temperature humidity co2].each do |metric|
      DeviceCapability.create!(
        device: device,
        key: "metric_#{metric}",
        name: metric.humanize,
        capability_type: "sensor",
        configuration: { "metric" => metric },
        state: { "value" => 1, "unit" => metric == "humidity" ? "%" : "F", "status" => "available" }
      )
    end

    dashboard = Home::DashboardProvisioner.new(user: @user).home_dashboard

    assert_equal 11, dashboard.dashboard_tiles.count
    assert_equal 11, dashboard.dashboard_widgets.count
    assert_equal 3, dashboard.dashboard_widgets.joins(device_capability: { device: { service_connection: :service_provider } }).where(service_providers: { key: "polar" }).count
  end
end
