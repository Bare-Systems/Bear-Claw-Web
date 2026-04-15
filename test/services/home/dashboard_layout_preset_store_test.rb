require "test_helper"
require "securerandom"

class Home::DashboardLayoutPresetStoreTest < ActiveSupport::TestCase
  setup do
    token = SecureRandom.hex(6)
    @user = User.create!(
      email: "dashboard-preset-store-#{token}@example.com",
      google_uid: "dashboard-preset-store-#{token}",
      name: "Dashboard Preset Store #{token}",
      role: :operator
    )
    @dashboard = Dashboard.fetch_or_create_for!(user: @user, context: :home, name: "Preset Dashboard")
    @dashboard.update!(settings: @dashboard.settings_hash.merge("columns" => 8))
    @tile = @dashboard.dashboard_tiles.create!(title: "Camera Tile", row: 1, column: 1, width: 2, height: 2, position: 1)
  end

  test "saves and overwrites a named layout preset" do
    store = Home::DashboardLayoutPresetStore.new(dashboard: @dashboard)
    @tile.update!(settings: @tile.settings_hash.merge("section" => "Cameras"))

    store.save!(name: "Focus")
    assert_equal [ "Focus" ], @dashboard.reload.layout_presets.map { |preset| preset.fetch("name") }
    assert_equal 1, @dashboard.layout_presets.first.fetch("tiles").size
    assert_equal "Cameras", @dashboard.layout_presets.first.fetch("tiles").first.fetch("section")

    @tile.update!(row: 2, column: 5, width: 4, height: 3)
    store.save!(name: "Focus")

    preset = @dashboard.reload.layout_presets.first
    snapshot = preset.fetch("tiles").first
    assert_equal 2, snapshot.fetch("row")
    assert_equal 5, snapshot.fetch("column")
    assert_equal 4, snapshot.fetch("width")
    assert_equal 3, snapshot.fetch("height")
  end

  test "deletes a saved layout preset" do
    store = Home::DashboardLayoutPresetStore.new(dashboard: @dashboard)
    store.save!(name: "Focus")

    assert store.delete!(name: "Focus")
    assert_empty @dashboard.reload.layout_presets
  end
end
