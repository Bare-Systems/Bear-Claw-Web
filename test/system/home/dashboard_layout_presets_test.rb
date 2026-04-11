require "application_system_test_case"
require "securerandom"

class Home::DashboardLayoutPresetsTest < ApplicationSystemTestCase
  setup do
    HouseholdMembership.delete_all
    Household.delete_all

    token = SecureRandom.hex(6)
    @user = User.create!(
      email: "dashboard-layout-presets-system-#{token}@example.com",
      google_uid: "dashboard-layout-presets-system-#{token}",
      name: "Dashboard Layout Presets System #{token}",
      role: :operator
    )

    household = Household.create!(name: "Layout Presets Home #{token}", owner: @user)
    HouseholdMembership.create!(household: household, user: @user)

    @dashboard = Dashboard.fetch_or_create_for!(user: @user, context: :home, name: "Layout Lab")
    @dashboard.update!(settings: @dashboard.settings_hash.merge("columns" => 8))
    @first_tile = @dashboard.dashboard_tiles.create!(title: "Alpha", row: 1, column: 1, width: 2, height: 2, position: 1)
    @second_tile = @dashboard.dashboard_tiles.create!(title: "Beta", row: 1, column: 3, width: 2, height: 2, position: 2)
  end

  test "saves and reapplies a named layout preset from the editor" do
    visit "/dev/login?email=#{@user.email}"
    visit home_root_path(edit: 1, dashboard: @dashboard.name)

    within "section", text: "Layout Presets" do
      fill_in "Preset Name", with: "Focus View"
      click_button "Save Layout Preset"
    end

    assert_text "Focus View saved."
    assert_text "Focus View"

    @first_tile.update!(row: 2, column: 5, width: 4, height: 3)
    @second_tile.update!(row: 1, column: 1, width: 2, height: 2)

    visit home_root_path(edit: 1, dashboard: @dashboard.name)
    within "#tile-#{@first_tile.id}" do
      assert_text "Row 2"
      assert_text "Column 5"
      assert_text "Size 4×3"
    end

    within "section", text: "Layout Presets" do
      click_button "Apply Focus View"
    end

    assert_text "Focus View applied."
    within "#tile-#{@first_tile.id}" do
      assert_text "Row 1"
      assert_text "Column 1"
      assert_text "Size 2×2"
    end
  end
end
