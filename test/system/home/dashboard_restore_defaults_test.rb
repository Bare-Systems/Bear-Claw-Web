require "application_system_test_case"
require "securerandom"

class Home::DashboardRestoreDefaultsTest < ApplicationSystemTestCase
  setup do
    HouseholdMembership.delete_all
    Household.delete_all

    token = SecureRandom.hex(6)
    @user = User.create!(
      email: "dashboard-restore-defaults-#{token}@example.com",
      google_uid: "dashboard-restore-defaults-#{token}",
      name: "Dashboard Restore Defaults #{token}",
      role: :operator
    )

    household = Household.create!(name: "Restore Defaults Home #{token}", owner: @user)
    HouseholdMembership.create!(household: household, user: @user)

    provider = ServiceProvider.create!(key: "koala", name: "Koala", provider_type: "hybrid")
    connection = ServiceConnection.create!(
      service_provider: provider,
      key: "koala-main-#{token}",
      name: "Koala Main",
      adapter: "koala",
      credential_strategy: "environment",
      status: "online",
      base_url: "http://koala.test"
    )

    (1..4).each do |index|
      device = Device.create!(
        service_connection: connection,
        user: @user,
        key: "restore-camera-#{index}",
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

    @dashboard = Home::DashboardProvisioner.new(user: @user).home_dashboard
    @dashboard = Home::DashboardDensityUpgrader.new(dashboard: @dashboard).upgrade!
  end

  test "restore defaults removes custom tiles and rebuilds the seeded layout" do
    visit "/dev/login?email=#{@user.email}"
    visit home_root_path(edit: 1, dashboard: @dashboard.name)

    within "section", text: "Add Tile" do
      fill_in "Title", with: "Scratch Pad"
      click_button "Create Tile"
    end

    assert_text "Scratch Pad"

    within "section", text: "Layout History" do
      accept_confirm do
        click_button "Restore Defaults"
      end
    end

    assert_no_text "Scratch Pad"
    assert_text "CAM 1"
    assert_text "CAM 4"

    within "section", text: "Layout History" do
      assert_text "Before restore defaults"
    end
  end
end
