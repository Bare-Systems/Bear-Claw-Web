require "test_helper"
require "securerandom"

class HomeHelperTest < ActionView::TestCase
  include ActiveSupport::Testing::TimeHelpers

  setup do
    token = SecureRandom.hex(6)
    @user = User.create!(
      email: "home-helper-#{token}@example.com",
      google_uid: "home-helper-#{token}",
      name: "Home Helper #{token}",
      role: :operator
    )

    provider = ServiceProvider.create!(key: "home-helper-#{token}", name: "Helper Provider", provider_type: "network")
    connection = ServiceConnection.create!(
      service_provider: provider,
      key: "home-helper-connection-#{token}",
      name: "Helper Connection",
      adapter: "custom",
      credential_strategy: "environment",
      status: "online",
      base_url: "http://helper.test"
    )
    device = Device.create!(
      service_connection: connection,
      user: @user,
      key: "helper-device-#{token}",
      name: "Helper Device",
      category: "sensor",
      source_kind: "network",
      source_identifier: "helper",
      status: "available"
    )
    @capability = DeviceCapability.create!(
      device: device,
      key: "helper-status",
      name: "Helper Status",
      capability_type: "status",
      state: {}
    )
    dashboard = Dashboard.fetch_or_create_for!(user: @user, context: :home, name: "Helper Dashboard")
    @tile = dashboard.dashboard_tiles.create!(title: "Health Tile", row: 1, column: 1, width: 2, height: 2, position: 1)
    @widget = @tile.dashboard_widgets.create!(
      device_capability: @capability,
      widget_type: "status_badge",
      title: "Helper Widget",
      position: 1
    )
  end

  test "classifies fresh stale offline and unknown widget health states" do
    travel_to Time.zone.parse("2026-04-11 10:00:00") do
      @capability.update!(state: { "status" => "available", "last_seen_at" => 2.minutes.ago.iso8601 })
      assert_equal :healthy, dashboard_widget_health_state(@widget)
      assert_equal "Fresh", dashboard_widget_health_label(@widget)
      assert_equal "Updated 2 minutes ago", dashboard_widget_health_detail(@widget)

      @capability.update!(state: { "status" => "available", "last_seen_at" => 20.minutes.ago.iso8601 })
      assert_equal :stale, dashboard_widget_health_state(@widget)
      assert_equal "Stale", dashboard_widget_health_label(@widget)
      assert_equal "Last update 20 minutes ago", dashboard_widget_health_detail(@widget)

      @capability.update!(state: { "status" => "offline", "last_seen_at" => 1.minute.ago.iso8601, "last_error" => "Gateway timeout" })
      assert_equal :offline, dashboard_widget_health_state(@widget)
      assert_equal "Offline", dashboard_widget_health_label(@widget)
      assert_equal "Gateway timeout", dashboard_widget_health_detail(@widget)

      @capability.update!(state: {})
      assert_equal :unknown, dashboard_widget_health_state(@widget)
      assert_equal "Awaiting sync", dashboard_widget_health_label(@widget)
      assert_equal "Awaiting first sync", dashboard_widget_health_detail(@widget)
    end
  end

  test "aggregates the worst widget state onto the tile" do
    travel_to Time.zone.parse("2026-04-11 10:00:00") do
      second_capability = DeviceCapability.create!(
        device: @capability.device,
        key: "helper-sensor",
        name: "Helper Sensor",
        capability_type: "sensor",
        state: { "status" => "available", "last_seen_at" => 3.minutes.ago.iso8601 }
      )
      @tile.dashboard_widgets.create!(
        device_capability: second_capability,
        widget_type: "sensor_stat",
        title: "Second Widget",
        position: 2
      )

      @capability.update!(state: { "status" => "available", "last_seen_at" => 25.minutes.ago.iso8601 })
      assert_equal :stale, dashboard_tile_health_state(@tile)
      assert_equal "Stale", dashboard_tile_health_label(@tile)

      @capability.update!(state: { "status" => "offline", "last_error" => "No route to host" })
      assert_equal :offline, dashboard_tile_health_state(@tile)
      assert_equal "Offline", dashboard_tile_health_label(@tile)
    end
  end

  test "derives compact mobile spans and heights from tile content" do
    assert_equal 1, dashboard_tile_mobile_span(@tile)
    assert_equal 2, dashboard_tile_mobile_height(@tile)

    camera_capability = DeviceCapability.create!(
      device: @capability.device,
      key: "helper-camera",
      name: "Helper Camera",
      capability_type: "camera_feed",
      configuration: { "camera_id" => "cam-helper" },
      state: { "status" => "available" }
    )

    @tile.dashboard_widgets.create!(
      device_capability: camera_capability,
      widget_type: "camera_feed",
      title: "Camera Widget",
      position: 2
    )

    @tile.update!(width: 4, height: 4)

    assert_equal 2, dashboard_tile_mobile_span(@tile)
    assert_equal 3, dashboard_tile_mobile_height(@tile)
    assert_includes dashboard_tile_style(@tile), "--tile-mobile-span: 2"
    assert_includes dashboard_tile_style(@tile), "--tile-mobile-height: 3"
  end

  test "builds ranked dashboard alerts for stale offline and error widgets" do
    travel_to Time.zone.parse("2026-04-11 10:00:00") do
      @capability.update!(state: { "status" => "offline", "last_seen_at" => 1.minute.ago.iso8601, "last_error" => "Gateway timeout" })
      @tile.update!(settings: @tile.settings_hash.merge("section" => "Security"))

      stale_capability = DeviceCapability.create!(
        device: @capability.device,
        key: "helper-stale",
        name: "Helper Stale",
        capability_type: "sensor",
        state: { "status" => "available", "last_seen_at" => 20.minutes.ago.iso8601 }
      )
      stale_tile = @tile.dashboard.dashboard_tiles.create!(
        title: "Stale Tile",
        row: 1,
        column: 3,
        width: 2,
        height: 2,
        position: 2,
        settings: { "section" => "Air" }
      )
      stale_tile.dashboard_widgets.create!(
        device_capability: stale_capability,
        widget_type: "sensor_stat",
        title: "Stale Reading",
        position: 1
      )

      error_capability = DeviceCapability.create!(
        device: @capability.device,
        key: "helper-error",
        name: "Helper Error",
        capability_type: "status",
        state: { "status" => "available", "last_seen_at" => 1.minute.ago.iso8601, "last_error" => "Probe failed" }
      )
      error_tile = @tile.dashboard.dashboard_tiles.create!(
        title: "Error Tile",
        row: 1,
        column: 5,
        width: 2,
        height: 2,
        position: 3,
        settings: { "section" => "Operations" }
      )
      error_tile.dashboard_widgets.create!(
        device_capability: error_capability,
        widget_type: "status_badge",
        title: "Error Badge",
        position: 1
      )

      alerts = dashboard_alerts_for_tiles(@tile.dashboard.dashboard_tiles.order(:position), limit: 10)

      assert_equal [ "Offline", "Error", "Stale" ], alerts.map { |alert| alert[:label] }
      assert_equal [ "Health Tile", "Error Tile", "Stale Tile" ], alerts.map { |alert| alert[:tile].display_title }
      assert_equal "Gateway timeout", alerts.first[:detail]
      assert_equal "Probe failed", alerts.second[:detail]
      assert_equal "Security", alerts.first[:section_name]
      assert_equal "Stale Reading", alerts.third[:widget].display_title
    end
  end
end
