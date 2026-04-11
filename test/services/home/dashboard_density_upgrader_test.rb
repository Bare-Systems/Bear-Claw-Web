require "test_helper"
require "securerandom"

class Home::DashboardDensityUpgraderTest < ActiveSupport::TestCase
  setup do
    token = SecureRandom.hex(6)
    @user = User.create!(
      email: "dashboard-density-#{token}@example.com",
      google_uid: "dashboard-density-#{token}",
      name: "Dashboard Density #{token}",
      role: :operator
    )
    @dashboard = Dashboard.fetch_or_create_for!(user: @user, context: :home, name: "Density Dashboard")
    @dashboard.update!(settings: { "columns" => 4 })

    @tile_a = @dashboard.dashboard_tiles.create!(title: "A", row: 1, column: 1, width: 1, height: 1, position: 1)
    @tile_b = @dashboard.dashboard_tiles.create!(title: "B", row: 1, column: 2, width: 2, height: 1, position: 2)
    @tile_c = @dashboard.dashboard_tiles.create!(title: "C", row: 2, column: 1, width: 1, height: 2, position: 3)
  end

  test "upgrades a legacy 4-column layout to an 8-column dense grid" do
    Home::DashboardDensityUpgrader.new(dashboard: @dashboard).upgrade!

    assert_equal 8, @dashboard.reload.columns
    assert_equal [ 1, 1, 2, 2 ], [ @tile_a.reload.row, @tile_a.column, @tile_a.width, @tile_a.height ]
    assert_equal [ 1, 3, 4, 2 ], [ @tile_b.reload.row, @tile_b.column, @tile_b.width, @tile_b.height ]
    assert_equal [ 1, 7, 2, 4 ], [ @tile_c.reload.row, @tile_c.column, @tile_c.width, @tile_c.height ]
  end

  test "does not re-upgrade an already dense dashboard" do
    @dashboard.update!(settings: { "columns" => 8, "density_version" => 2 })

    Home::DashboardDensityUpgrader.new(dashboard: @dashboard).upgrade!

    assert_equal [ 1, 1, 1, 1 ], [ @tile_a.reload.row, @tile_a.column, @tile_a.width, @tile_a.height ]
    assert_equal 8, @dashboard.reload.columns
  end
end
