require "application_system_test_case"
require "securerandom"

class Home::WidgetPickerTest < ApplicationSystemTestCase
  setup do
    HouseholdMembership.delete_all
    Household.delete_all

    token = SecureRandom.hex(6)
    @user = User.create!(
      email: "widget-picker-#{token}@example.com",
      google_uid: "widget-picker-#{token}",
      name: "Widget Picker #{token}",
      role: :operator
    )

    household = Household.create!(name: "System Test Home #{token}", owner: @user)
    HouseholdMembership.create!(household: household, user: @user)

    koala_provider = ServiceProvider.create!(key: "koala-#{token}", name: "Koala", provider_type: "hybrid")
    koala_connection = ServiceConnection.create!(
      service_provider: koala_provider,
      key: "koala-main-system-test-#{token}",
      name: "Koala Main",
      adapter: "koala",
      credential_strategy: "environment",
      status: "online",
      base_url: "http://koala.test"
    )
    camera_device = Device.create!(
      service_connection: koala_connection,
      user: @user,
      key: "front-door-camera",
      name: "Front Door Camera",
      category: "camera",
      source_kind: "physical",
      source_identifier: "cam_1",
      status: "available"
    )
    @camera_capability = DeviceCapability.create!(
      device: camera_device,
      key: "front_door_feed",
      name: "Front Door Feed",
      capability_type: "camera_feed",
      configuration: { "camera_id" => "cam_1" },
      state: { "status" => "available" }
    )

    polar_provider = ServiceProvider.create!(key: "polar-#{token}", name: "Polar", provider_type: "network")
    polar_connection = ServiceConnection.create!(
      service_provider: polar_provider,
      key: "polar-main-system-test-#{token}",
      name: "Polar Main",
      adapter: "polar",
      credential_strategy: "environment",
      status: "online",
      base_url: "http://polar.test"
    )
    sensor_device = Device.create!(
      service_connection: polar_connection,
      user: @user,
      key: "air-quality-indoor",
      name: "Air Quality Station",
      category: "sensor",
      source_kind: "network",
      source_identifier: "indoor",
      status: "available"
    )
    @sensor_capability = DeviceCapability.create!(
      device: sensor_device,
      key: "air_quality",
      name: "Air Quality",
      capability_type: "sensor",
      configuration: { "metric" => "co2" },
      state: { "value" => 640, "unit" => "ppm", "status" => "available" }
    )

    dashboard = Dashboard.fetch_or_create_for!(user: @user, context: :home, name: "Home Dashboard")
    @tile = dashboard.dashboard_tiles.create!(
      title: "Operations Tile",
      row: 1,
      column: 1,
      width: 1,
      height: 1,
      position: 1
    )
  end

  test "filters capabilities and updates widget recommendations" do
    login_as_test_user
    visit home_root_path(edit: 1)

    within "#tile-editor-#{@tile.id}" do
      assert_selector "form[data-widget-picker-ready='true']"
      fill_in "Search Capabilities", with: "air quality"
      assert_selector "label:not([hidden])", text: "Air Quality"
      assert_no_selector "label:not([hidden])", text: "Front Door Feed"

      fill_in "Search Capabilities", with: ""
      select "Sensor", from: "Capability Type"
      assert_selector "label:not([hidden])", text: "Air Quality"
      assert_no_selector "label:not([hidden])", text: "Front Door Feed"

      choose "widget-picker-tile-#{@tile.id}-capability-#{@sensor_capability.id}"

      assert_text "Polar"
      assert_text "Air Quality Station"
      assert_text "Sensor"
      assert_text "Sensor Reading"

      widget_type_options = find("select[name='dashboard_widget[widget_type]']").all("option").map(&:text)

      assert_includes widget_type_options, "Use capability default (Sensor Reading)"
      assert_includes widget_type_options, "Sensor Reading"
      assert_includes widget_type_options, "Air Quality Card"
      assert_includes widget_type_options, "Status Badge"
      assert_not_includes widget_type_options, "Switch Control"
    end
  end

  test "adds a widget through the searchable capability picker" do
    login_as_test_user
    visit home_root_path(edit: 1)

    within "#tile-editor-#{@tile.id}" do
      assert_selector "form[data-widget-picker-ready='true']"
      fill_in "Search Capabilities", with: "front door"
      choose "widget-picker-tile-#{@tile.id}-capability-#{@camera_capability.id}"
      find("input[name='dashboard_widget[title]']").set("Front Door Status")
      find("select[name='dashboard_widget[widget_type]']").select("Status Badge")
      click_button "Add Widget"
    end

    assert_text "Widget added."
    assert_text "Front Door Status"
  end

  private

  def login_as_test_user
    visit "/dev/login?email=#{@user.email}"
  end
end
