require "test_helper"
require "securerandom"

class Home::DashboardLayoutPresetsControllerTest < ActionController::TestCase
  tests Home::DashboardLayoutPresetsController

  setup do
    token = SecureRandom.hex(6)
    @user = User.create!(
      email: "dashboard-layout-presets-#{token}@example.com",
      google_uid: "dashboard-layout-presets-#{token}",
      name: "Dashboard Layout Presets #{token}",
      role: :operator
    )
    @request.session[:user_id] = @user.id
    @dashboard = Dashboard.fetch_or_create_for!(user: @user, context: :home, name: "Layout Lab")
    @dashboard.update!(settings: @dashboard.settings_hash.merge("columns" => 8))
    @tile = @dashboard.dashboard_tiles.create!(title: "Tile A", row: 1, column: 1, width: 2, height: 2, position: 1)
  end

  test "creates a named layout preset for the dashboard" do
    post :create, params: { dashboard_id: @dashboard.id, layout_preset: { name: "Focus" } }

    assert_redirected_to home_root_path(edit: 1, dashboard: @dashboard.name)
    assert_equal [ "Focus" ], @dashboard.reload.layout_presets.map { |preset| preset.fetch("name") }
  end

  test "applies a saved layout preset" do
    Home::DashboardLayoutPresetStore.new(dashboard: @dashboard).save!(name: "Focus")
    @tile.update!(row: 2, column: 5, width: 4, height: 3)

    post :apply, params: { dashboard_id: @dashboard.id, name: "Focus" }

    assert_redirected_to home_root_path(edit: 1, dashboard: @dashboard.name)
    assert_equal [ 1, 1, 2, 2 ], [ @tile.reload.row, @tile.column, @tile.width, @tile.height ]
  end

  test "destroys a saved layout preset" do
    Home::DashboardLayoutPresetStore.new(dashboard: @dashboard).save!(name: "Focus")

    delete :destroy, params: { dashboard_id: @dashboard.id, name: "Focus" }

    assert_redirected_to home_root_path(edit: 1, dashboard: @dashboard.name)
    assert_empty @dashboard.reload.layout_presets
  end
end
