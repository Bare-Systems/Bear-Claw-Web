require "application_system_test_case"
require "securerandom"

class Home::DashboardSectionsTest < ApplicationSystemTestCase
  setup do
    HouseholdMembership.delete_all
    Household.delete_all

    token = SecureRandom.hex(6)
    @user = User.create!(
      email: "dashboard-sections-system-#{token}@example.com",
      google_uid: "dashboard-sections-system-#{token}",
      name: "Dashboard Sections System #{token}",
      role: :operator
    )

    household = Household.create!(name: "Sections Home #{token}", owner: @user)
    HouseholdMembership.create!(household: household, user: @user)

    @dashboard = Dashboard.fetch_or_create_for!(user: @user, context: :home, name: "Sections Lab")
    @dashboard.update!(settings: @dashboard.settings_hash.merge("columns" => 8))
    @camera_tile = @dashboard.dashboard_tiles.create!(
      title: "Camera Watch",
      row: 1,
      column: 1,
      width: 2,
      height: 2,
      position: 1,
      settings: { "section" => "Cameras" }
    )
    @security_tile = @dashboard.dashboard_tiles.create!(
      title: "Security Pulse",
      row: 1,
      column: 3,
      width: 2,
      height: 2,
      position: 2,
      settings: { "section" => "Security" }
    )
  end

  test "switches between dashboard sections" do
    visit "/dev/login?email=#{@user.email}"
    visit home_root_path(dashboard: @dashboard.name)

    assert_text "Camera Watch"
    assert_text "Security Pulse"

    click_link "Security"

    assert_text "Security Pulse"
    assert_no_text "Camera Watch"
  end
end
