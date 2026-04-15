require "application_system_test_case"
require "securerandom"

class Home::DashboardAlertsTest < ApplicationSystemTestCase
  include ActiveSupport::Testing::TimeHelpers

  test "dashboard pins priority alerts and respects section filtering" do
    travel_to Time.zone.parse("2026-04-11 10:00:00") do
      HouseholdMembership.delete_all
      Household.delete_all

      token = SecureRandom.hex(6)
      user = User.create!(
        email: "dashboard-alerts-#{token}@example.com",
        google_uid: "dashboard-alerts-#{token}",
        name: "Dashboard Alerts #{token}",
        role: :operator
      )

      household = Household.create!(name: "Alerts Test Home #{token}", owner: user)
      HouseholdMembership.create!(household: household, user: user)

      provider = ServiceProvider.create!(key: "dashboard-alerts-#{token}", name: "Alerts Provider", provider_type: "network")
      connection = ServiceConnection.create!(
        service_provider: provider,
        key: "dashboard-alerts-connection-#{token}",
        name: "Alerts Connection",
        adapter: "custom",
        credential_strategy: "environment",
        status: "online",
        base_url: "http://alerts.test"
      )
      dashboard = Dashboard.fetch_or_create_for!(user: user, context: :home, name: "Home Dashboard")
      dashboard.update!(settings: dashboard.settings_hash.merge("columns" => 8))

      create_alert_tile(
        dashboard: dashboard,
        connection: connection,
        user: user,
        title: "Offline Perimeter",
        tile_position: 1,
        device_suffix: "offline",
        widget_title: "Perimeter Feed",
        widget_type: "status_badge",
        capability_type: "status",
        section: "Security",
        state: { "status" => "offline", "last_seen_at" => 1.minute.ago.iso8601, "last_error" => "Gateway timeout" }
      )

      create_alert_tile(
        dashboard: dashboard,
        connection: connection,
        user: user,
        title: "Stale Air",
        tile_position: 2,
        device_suffix: "stale",
        widget_title: "Air Reading",
        widget_type: "sensor_stat",
        capability_type: "sensor",
        section: "Air",
        state: { "status" => "available", "last_seen_at" => 20.minutes.ago.iso8601, "value" => 712, "unit" => "ppm" }
      )

      create_alert_tile(
        dashboard: dashboard,
        connection: connection,
        user: user,
        title: "Fresh Feed",
        tile_position: 3,
        device_suffix: "fresh",
        widget_title: "Fresh Feed",
        widget_type: "status_badge",
        capability_type: "status",
        section: "Security",
        state: { "status" => "available", "last_seen_at" => 2.minutes.ago.iso8601 }
      )

      visit "/dev/login?email=#{user.email}"
      visit home_root_path

      within "#dashboard-priority-watch" do
        assert_text "Offline Perimeter"
        assert_text "Stale Air"
        assert_no_text "Fresh Feed"
      end

      alert_labels = page.evaluate_script(<<~JS)
        Array.from(document.querySelectorAll("#dashboard-priority-watch [data-alert-label]")).map((node) => node.textContent.trim())
      JS

      assert_equal [ "Offline", "Stale" ], alert_labels

      click_link "Security"

      within "#dashboard-priority-watch" do
        assert_text "Offline Perimeter"
        assert_no_text "Stale Air"
      end
    end
  end

  private

  def create_alert_tile(dashboard:, connection:, user:, title:, tile_position:, device_suffix:, widget_title:, widget_type:, capability_type:, section:, state:)
    device = Device.create!(
      service_connection: connection,
      user: user,
      key: "dashboard-alerts-device-#{device_suffix}",
      name: "#{title} Device",
      category: "network_service",
      source_kind: "network",
      source_identifier: device_suffix,
      status: state.fetch("status", "available") == "offline" ? "unavailable" : state.fetch("status", "available")
    )
    capability = DeviceCapability.create!(
      device: device,
      key: "dashboard-alerts-capability-#{device_suffix}",
      name: "#{title} Capability",
      capability_type: capability_type,
      state: state
    )
    tile = dashboard.dashboard_tiles.create!(
      title: title,
      row: 1,
      column: ((tile_position - 1) * 2) + 1,
      width: 2,
      height: 2,
      position: tile_position,
      settings: { "section" => section }
    )
    tile.dashboard_widgets.create!(
      device_capability: capability,
      widget_type: widget_type,
      title: widget_title,
      position: 1
    )
  end
end
