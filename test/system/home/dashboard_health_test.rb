require "application_system_test_case"
require "securerandom"

class Home::DashboardHealthTest < ApplicationSystemTestCase
  include ActiveSupport::Testing::TimeHelpers

  test "dashboard surfaces fresh stale and offline widget health" do
    travel_to Time.zone.parse("2026-04-11 10:00:00") do
      HouseholdMembership.delete_all
      Household.delete_all

      token = SecureRandom.hex(6)
      user = User.create!(
        email: "dashboard-health-#{token}@example.com",
        google_uid: "dashboard-health-#{token}",
        name: "Dashboard Health #{token}",
        role: :operator
      )

      household = Household.create!(name: "Health Test Home #{token}", owner: user)
      HouseholdMembership.create!(household: household, user: user)

      provider = ServiceProvider.create!(key: "dashboard-health-#{token}", name: "Health Provider", provider_type: "network")
      connection = ServiceConnection.create!(
        service_provider: provider,
        key: "dashboard-health-connection-#{token}",
        name: "Health Connection",
        adapter: "custom",
        credential_strategy: "environment",
        status: "online",
        base_url: "http://health.test"
      )
      dashboard = Dashboard.fetch_or_create_for!(user: user, context: :home, name: "Home Dashboard")
      dashboard.update!(settings: dashboard.settings_hash.merge("columns" => 8))

      fresh_tile = create_health_tile(
        dashboard: dashboard,
        connection: connection,
        user: user,
        title: "Fresh Tile",
        tile_position: 1,
        device_suffix: "fresh",
        widget_title: "Fresh Status",
        state: { "status" => "available", "last_seen_at" => 2.minutes.ago.iso8601 },
        expected_label: "Fresh",
        expected_detail: "Updated 2 minutes ago"
      )

      stale_tile = create_health_tile(
        dashboard: dashboard,
        connection: connection,
        user: user,
        title: "Stale Tile",
        tile_position: 2,
        device_suffix: "stale",
        widget_title: "Stale Status",
        state: { "status" => "available", "last_seen_at" => 20.minutes.ago.iso8601 },
        expected_label: "Stale",
        expected_detail: "Last update 20 minutes ago"
      )

      offline_tile = create_health_tile(
        dashboard: dashboard,
        connection: connection,
        user: user,
        title: "Offline Tile",
        tile_position: 3,
        device_suffix: "offline",
        widget_title: "Offline Status",
        state: { "status" => "offline", "last_seen_at" => 1.minute.ago.iso8601, "last_error" => "Gateway timeout" },
        expected_label: "Offline",
        expected_detail: "Gateway timeout"
      )

      visit "/dev/login?email=#{user.email}"
      visit home_root_path

      assert_tile_health(fresh_tile[:tile], fresh_tile[:expected_label], fresh_tile[:expected_detail])
      assert_tile_health(stale_tile[:tile], stale_tile[:expected_label], stale_tile[:expected_detail])
      assert_tile_health(offline_tile[:tile], offline_tile[:expected_label], offline_tile[:expected_detail])
    end
  end

  private

  def create_health_tile(dashboard:, connection:, user:, title:, tile_position:, device_suffix:, widget_title:, state:, expected_label:, expected_detail:)
    device = Device.create!(
      service_connection: connection,
      user: user,
      key: "dashboard-health-device-#{device_suffix}",
      name: "#{title} Device",
      category: "network_service",
      source_kind: "network",
      source_identifier: device_suffix,
      status: state.fetch("status", "available") == "offline" ? "unavailable" : state.fetch("status", "available")
    )
    capability = DeviceCapability.create!(
      device: device,
      key: "dashboard-health-capability-#{device_suffix}",
      name: "#{title} Capability",
      capability_type: "status",
      state: state
    )
    tile = dashboard.dashboard_tiles.create!(
      title: title,
      row: 1,
      column: ((tile_position - 1) * 2) + 1,
      width: 2,
      height: 2,
      position: tile_position
    )
    tile.dashboard_widgets.create!(
      device_capability: capability,
      widget_type: "status_badge",
      title: widget_title,
      position: 1
    )

    { tile: tile, expected_label: expected_label, expected_detail: expected_detail }
  end

  def assert_tile_health(tile, label, detail)
    within "#tile-#{tile.id}" do
      assert_text label
      assert_text detail
    end
  end
end
