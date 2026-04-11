require "application_system_test_case"
require "securerandom"

class Home::DashboardLayoutHistoryTest < ApplicationSystemTestCase
  setup do
    HouseholdMembership.delete_all
    Household.delete_all

    token = SecureRandom.hex(6)
    @user = User.create!(
      email: "dashboard-layout-history-system-#{token}@example.com",
      google_uid: "dashboard-layout-history-system-#{token}",
      name: "Dashboard Layout History System #{token}",
      role: :operator
    )

    household = Household.create!(name: "Layout History Home #{token}", owner: @user)
    HouseholdMembership.create!(household: household, user: @user)

    @dashboard = Dashboard.fetch_or_create_for!(user: @user, context: :home, name: "History Lab")
    @dashboard.update!(settings: @dashboard.settings_hash.merge("columns" => 8))
  end

  test "undoes the last layout change from the editor" do
    visit "/dev/login?email=#{@user.email}"
    visit home_root_path(edit: 1, dashboard: @dashboard.name)

    within "section", text: "Add Tile" do
      fill_in "Title", with: "Scratch Pad"
      click_button "Create Tile"
    end

    assert_text "Tile added."
    assert_text "Scratch Pad"

    within "section", text: "Layout History" do
      click_button "Undo Last Change"
    end

    assert_text "Last layout change undone."
    assert_no_text "Scratch Pad"
  end
end
