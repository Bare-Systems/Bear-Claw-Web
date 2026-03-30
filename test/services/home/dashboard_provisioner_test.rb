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
        user: @user,
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

  test "seeds a Home Dashboard with 8 camera tiles on first call" do
    provisioner = Home::DashboardProvisioner.new(user: @user)
    dashboard = provisioner.home_dashboard

    assert_equal "Home Dashboard", dashboard.name
    assert_equal 8, dashboard.dashboard_tiles.count
    assert_equal 8, dashboard.dashboard_widgets.count
  end

  test "all_dashboards returns three named dashboards" do
    dashboards = Home::DashboardProvisioner.new(user: @user).all_dashboards

    assert_equal 3, dashboards.size
    assert_equal [ "Home Dashboard", "Finances Dashboard", "Security Overview" ], dashboards.map(&:name)
  end

  test "calling home_dashboard twice does not duplicate tiles" do
    provisioner = Home::DashboardProvisioner.new(user: @user)
    provisioner.home_dashboard
    provisioner.home_dashboard

    assert_equal 8, DashboardTile.where(dashboard: Dashboard.find_by(name: "Home Dashboard")).count
  end

  test "adds polar air quality tiles when dashboard is on the default 8-camera layout" do
    polar_provider = ServiceProvider.create!(key: "polar", name: "Polar", provider_type: "network")
    polar_connection = ServiceConnection.create!(
      service_provider: polar_provider,
      key: "polar-main",
      name: "Polar Main",
      adapter: "polar",
      credential_strategy: "environment",
      status: "online",
      base_url: "http://192.168.86.53:6702"
    )
    device = Device.create!(
      service_connection: polar_connection,
      user: @user,
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
    assert_equal 3,
      dashboard.dashboard_widgets
        .joins(device_capability: { device: { service_connection: :service_provider } })
        .where(service_providers: { key: "polar" })
        .count
  end

  test "Finances Dashboard seeds Kodiak portfolio capabilities as finance tiles" do
    kodiak_provider = ServiceProvider.create!(key: "kodiak", name: "Kodiak", provider_type: "network")
    kodiak_connection = ServiceConnection.create!(
      service_provider: kodiak_provider,
      key: "kodiak",
      name: "Kodiak",
      adapter: "kodiak",
      credential_strategy: "environment",
      status: "online",
      base_url: "http://192.168.86.53:8000"
    )
    portfolio_device = Device.create!(
      service_connection: kodiak_connection,
      user: @user,
      key: "kodiak-portfolio",
      name: "Kodiak Portfolio",
      category: "network_service",
      source_kind: "network",
      source_identifier: "kodiak:portfolio",
      status: "available"
    )
    %w[portfolio_equity portfolio_cash portfolio_day_pnl].each do |key|
      DeviceCapability.create!(
        device: portfolio_device,
        key: key,
        name: key.humanize,
        capability_type: "finance",
        configuration: { "metric" => key.sub("portfolio_", ""), "service" => "kodiak" },
        state: { "value" => 1.0, "unit" => "USD" }
      )
    end

    dashboards = Home::DashboardProvisioner.new(user: @user).all_dashboards
    finances = dashboards.find { |d| d.name == "Finances Dashboard" }

    assert_equal 3, finances.dashboard_tiles.count
    assert finances.dashboard_widgets.all? { |w| w.widget_type == "portfolio_stat" }
  end

  test "Security Overview seeds Ursa capabilities as security_stat tiles" do
    ursa_provider = ServiceProvider.create!(key: "ursa", name: "Ursa", provider_type: "network")
    ursa_connection = ServiceConnection.create!(
      service_provider: ursa_provider,
      key: "ursa",
      name: "Ursa",
      adapter: "ursa",
      credential_strategy: "environment",
      status: "online",
      base_url: "http://192.168.86.53:18080"
    )
    overview_device = Device.create!(
      service_connection: ursa_connection,
      user: @user,
      key: "ursa-overview",
      name: "Ursa C2",
      category: "network_service",
      source_kind: "network",
      source_identifier: "ursa:overview",
      status: "available"
    )
    %w[ursa_sessions ursa_campaigns].each do |key|
      DeviceCapability.create!(
        device: overview_device,
        key: key,
        name: key.humanize,
        capability_type: "status",
        configuration: { "service" => "ursa" },
        state: { "value" => 0 }
      )
    end

    dashboards = Home::DashboardProvisioner.new(user: @user).all_dashboards
    security = dashboards.find { |d| d.name == "Security Overview" }

    assert_equal 2, security.dashboard_tiles.count
    assert security.dashboard_widgets.all? { |w| w.widget_type == "security_stat" }
  end
end
