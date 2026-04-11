require "application_system_test_case"
require "securerandom"

class Home::DashboardQuickAddPackTest < ApplicationSystemTestCase
  setup do
    HouseholdMembership.delete_all
    Household.delete_all

    token = SecureRandom.hex(6)
    @user = User.create!(
      email: "dashboard-pack-#{token}@example.com",
      google_uid: "dashboard-pack-#{token}",
      name: "Dashboard Pack #{token}",
      role: :operator
    )

    household = Household.create!(name: "Pack Test Home #{token}", owner: @user)
    HouseholdMembership.create!(household: household, user: @user)

    provider = ServiceProvider.create!(key: "koala", name: "Koala", provider_type: "hybrid")
    connection = ServiceConnection.create!(
      service_provider: provider,
      key: "koala-pack-system-test-#{token}",
      name: "Koala Main",
      adapter: "koala",
      credential_strategy: "environment",
      status: "online",
      base_url: "http://koala.test"
    )

    2.times do |index|
      device = Device.create!(
        service_connection: connection,
        user: @user,
        key: "quick-pack-camera-#{token}-#{index}",
        name: "Quick Camera #{index + 1}",
        category: "camera",
        source_kind: "physical",
        source_identifier: "quick_cam_#{index + 1}",
        status: "available"
      )
      DeviceCapability.create!(
        device: device,
        key: "feed_#{index}",
        name: "Quick Camera #{index + 1} Feed",
        capability_type: "camera_feed",
        configuration: { "camera_id" => "quick_cam_#{index + 1}" },
        state: { "status" => "available" }
      )
    end
  end

  test "adds a quick-add pack from the dashboard editor" do
    visit "/dev/login?email=#{@user.email}"
    visit home_root_path(edit: 1, dashboard: "Finances Dashboard")

    assert_text "Finances Dashboard"
    assert_text "Quick Add Packs"
    click_button "Add Camera Wall"

    assert_text "Camera Wall added."
    assert_text "Quick Camera 1"
    assert_text "Quick Camera 2"
  end
end
