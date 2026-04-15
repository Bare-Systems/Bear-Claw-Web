require "application_system_test_case"
require "securerandom"

class Home::DashboardMobileLayoutTest < ApplicationSystemTestCase
  setup do
    HouseholdMembership.delete_all
    Household.delete_all

    token = SecureRandom.hex(6)
    @user = User.create!(
      email: "dashboard-mobile-#{token}@example.com",
      google_uid: "dashboard-mobile-#{token}",
      name: "Dashboard Mobile #{token}",
      role: :operator
    )

    household = Household.create!(name: "Dashboard Mobile #{token}", owner: @user)
    HouseholdMembership.create!(household: household, user: @user)

    provider = ServiceProvider.create!(key: "mobile-provider-#{token}", name: "Mobile Provider", provider_type: "hybrid")
    connection = ServiceConnection.create!(
      service_provider: provider,
      key: "mobile-connection-#{token}",
      name: "Mobile Connection",
      adapter: "custom",
      credential_strategy: "environment",
      status: "online",
      base_url: "http://mobile.test"
    )

    camera_device = Device.create!(
      service_connection: connection,
      user: @user,
      key: "mobile-camera-#{token}",
      name: "Mobile Camera",
      category: "camera",
      source_kind: "physical",
      source_identifier: "cam-mobile",
      status: "available"
    )
    camera_capability = DeviceCapability.create!(
      device: camera_device,
      key: "mobile-camera-feed-#{token}",
      name: "Driveway Camera",
      capability_type: "camera_feed",
      configuration: { "camera_id" => "cam-mobile" },
      state: { "status" => "available" }
    )

    sensor_device = Device.create!(
      service_connection: connection,
      user: @user,
      key: "mobile-sensor-#{token}",
      name: "Mobile Sensor",
      category: "sensor",
      source_kind: "network",
      source_identifier: "sensor-mobile",
      status: "available"
    )
    sensor_capability = DeviceCapability.create!(
      device: sensor_device,
      key: "mobile-sensor-reading-#{token}",
      name: "Indoor Air",
      capability_type: "sensor",
      configuration: { "metric" => "co2" },
      state: { "value" => 640, "unit" => "ppm", "status" => "available" }
    )

    @dashboard = Dashboard.fetch_or_create_for!(user: @user, context: :home, name: "Mobile Dashboard")
    @dashboard.update!(settings: @dashboard.settings_hash.merge("columns" => 8))

    @camera_tile = @dashboard.dashboard_tiles.create!(
      title: "Driveway",
      row: 1,
      column: 1,
      width: 4,
      height: 3,
      position: 1,
      settings: { "section" => "Cameras" }
    )
    @camera_tile.dashboard_widgets.create!(
      device_capability: camera_capability,
      widget_type: "camera_feed",
      title: "Driveway Camera",
      position: 1
    )

    @sensor_tile = @dashboard.dashboard_tiles.create!(
      title: "Indoor Air",
      row: 1,
      column: 5,
      width: 2,
      height: 2,
      position: 2,
      settings: { "section" => "Air" }
    )
    @sensor_tile.dashboard_widgets.create!(
      device_capability: sensor_capability,
      widget_type: "sensor_stat",
      title: "Indoor CO2",
      position: 1
    )
  end

  test "packs tiles into a compact two-column grid on mobile while keeping section tabs usable" do
    visit "/dev/login?email=#{@user.email}"
    page.current_window.resize_to(390, 900)
    visit home_root_path(dashboard: @dashboard.name)

    layout = page.evaluate_script(<<~JS)
      (() => {
        const grid = document.querySelector(".dashboard-grid")
        const cameraTile = document.querySelector("#tile-#{@camera_tile.id}")
        const sensorTile = document.querySelector("#tile-#{@sensor_tile.id}")
        const styles = window.getComputedStyle(grid)
        return {
          columnCount: styles.gridTemplateColumns.split(" ").filter(Boolean).length,
          cameraWidth: Math.round(cameraTile.getBoundingClientRect().width),
          sensorWidth: Math.round(sensorTile.getBoundingClientRect().width),
          cameraColumnEnd: window.getComputedStyle(cameraTile).gridColumnEnd,
          sectionTabsOverflowX: window.getComputedStyle(document.querySelector(".dashboard-section-tabs")).overflowX
        }
      })()
    JS

    assert_equal 2, layout["columnCount"]
    assert_match(/span 2/, layout["cameraColumnEnd"])
    assert_operator layout["cameraWidth"], :>, layout["sensorWidth"] * 1.7
    assert_includes [ "auto", "scroll" ], layout["sectionTabsOverflowX"]

    click_link "Air"

    assert_text "Indoor Air"
    assert_no_text "Driveway"
  end
end
