require "test_helper"
require "securerandom"

class Home::DashboardLayoutPresetApplierTest < ActiveSupport::TestCase
  setup do
    token = SecureRandom.hex(6)
    @user = User.create!(
      email: "dashboard-preset-applier-#{token}@example.com",
      google_uid: "dashboard-preset-applier-#{token}",
      name: "Dashboard Preset Applier #{token}",
      role: :operator
    )
    @dashboard = Dashboard.fetch_or_create_for!(user: @user, context: :home, name: "Preset Dashboard")
    @dashboard.update!(settings: @dashboard.settings_hash.merge("columns" => 8))
    @tile_a = @dashboard.dashboard_tiles.create!(title: "A", row: 1, column: 1, width: 2, height: 2, position: 1)
    @tile_b = @dashboard.dashboard_tiles.create!(title: "B", row: 1, column: 3, width: 2, height: 2, position: 2)
    @tile_c = @dashboard.dashboard_tiles.create!(title: "C", row: 3, column: 1, width: 2, height: 2, position: 3)
  end

  test "applies a saved layout preset to matching tiles and repacks extras" do
    preset = {
      "name" => "Operations",
      "tiles" => [
        { "tile_id" => @tile_a.id, "row" => 1, "column" => 5, "width" => 4, "height" => 3 },
        { "tile_id" => @tile_b.id, "row" => 1, "column" => 1, "width" => 4, "height" => 2 }
      ]
    }

    Home::DashboardLayoutPresetApplier.new(dashboard: @dashboard, preset: preset).apply!

    assert_equal [ 1, 5, 4, 3 ], [ @tile_a.reload.row, @tile_a.column, @tile_a.width, @tile_a.height ]
    assert_equal [ 1, 1, 4, 2 ], [ @tile_b.reload.row, @tile_b.column, @tile_b.width, @tile_b.height ]
    assert_equal [ 3, 1, 2, 2 ], [ @tile_c.reload.row, @tile_c.column, @tile_c.width, @tile_c.height ]
  end
end
