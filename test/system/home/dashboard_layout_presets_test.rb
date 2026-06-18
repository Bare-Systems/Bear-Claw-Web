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
    # Start at the post-upgrade density so the in-memory AR association on each tile
    # already reflects columns=80. If we start at columns=8, the density upgrader runs
    # on the first page visit and updates the DB, but the test-process @dashboard object
    # (cached on @first_tile via the inverse association) never gets reloaded — the server's
    # @dashboard.reload only updates the server-side copy. That leaves dashboard.columns=8
    # in the tile validation, so any width>8 update in the test fails with RecordInvalid.
    @dashboard.update!(settings: @dashboard.settings_hash.merge("columns" => 80, "density_version" => 3))
    @first_tile = @dashboard.dashboard_tiles.create!(title: "Alpha", row: 1, column: 1, width: 20, height: 20, position: 1)
    @second_tile = @dashboard.dashboard_tiles.create!(title: "Beta", row: 1, column: 21, width: 20, height: 20, position: 2)
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

    # Use 80-column-grid-appropriate sizes (density upgrader scaled ×10 on first
    # visit, so base unit is 20). Values of 4×3 are only ~55×41px — too small
    # for the tile header to be visible through overflow-hidden. 30×20 gives
    # ~411×274px, comfortably larger than the meta paragraph.
    @first_tile.update!(row: 2, column: 5, width: 30, height: 20)
    @second_tile.update!(row: 1, column: 1, width: 2, height: 2)

    visit home_root_path(edit: 1, dashboard: @dashboard.name)
    within "#tile-#{@first_tile.id}" do
      assert_text "Row 2"
      assert_text "Column 5"
      assert_text "Size 30×20"
    end

    within "section", text: "Layout Presets" do
      click_button "Apply Focus View"
    end

    assert_text "Focus View applied."
    within "#tile-#{@first_tile.id}" do
      assert_text "Row 1"
      assert_text "Column 1"
      assert_text "Size 20×20"
    end
  end
end
