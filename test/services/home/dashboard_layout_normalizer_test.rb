require "test_helper"
require "securerandom"

class Home::DashboardLayoutNormalizerTest < ActiveSupport::TestCase
  setup do
    token = SecureRandom.hex(6)
    @user = User.create!(
      email: "dashboard-normalizer-#{token}@example.com",
      google_uid: "dashboard-normalizer-#{token}",
      name: "Dashboard Normalizer #{token}",
      role: :operator
    )
    @dashboard = Dashboard.fetch_or_create_for!(user: @user, context: :home, name: "Normalizer Dashboard")

    @tile_a = @dashboard.dashboard_tiles.create!(title: "A", row: 1, column: 1, width: 1, height: 1, position: 1)
    @tile_b = @dashboard.dashboard_tiles.create!(title: "B", row: 1, column: 2, width: 1, height: 1, position: 2)
    @tile_c = @dashboard.dashboard_tiles.create!(title: "C", row: 1, column: 3, width: 2, height: 1, position: 3)
  end

  test "reflows surrounding tiles when an anchor tile moves into occupied space" do
    @tile_a.update!(row: 1, column: 2)

    Home::DashboardLayoutNormalizer.new(dashboard: @dashboard).normalize!(anchor_tile: @tile_a)

    assert_equal [ 1, 2 ], [ @tile_a.reload.row, @tile_a.column ]
    assert_equal [ 1, 1 ], [ @tile_b.reload.row, @tile_b.column ]
    assert_equal [ 1, 3 ], [ @tile_c.reload.row, @tile_c.column ]
    assert_equal [ [ 1, 1 ], [ 1, 2 ], [ 1, 3 ] ], [ @tile_b, @tile_a, @tile_c ].map { |tile| [ tile.reload.row, tile.column ] }
  end

  test "keeps tile positions sequential after normalization" do
    Home::DashboardLayoutNormalizer.new(dashboard: @dashboard).normalize!(anchor_tile: @tile_c)

    assert_equal [ 1, 2, 3 ], @dashboard.dashboard_tiles.order(:position).pluck(:position)
  end

  test "packs later tiles upward so empty cells are reused" do
    @tile_a.update!(width: 2, height: 2)
    @tile_b.update!(row: 3, column: 4)
    @tile_c.update!(row: 4, column: 1, width: 1, height: 1)

    Home::DashboardLayoutNormalizer.new(dashboard: @dashboard).normalize!(anchor_tile: @tile_a)

    assert_equal [ 1, 1 ], [ @tile_a.reload.row, @tile_a.column ]
    assert_equal [ 1, 3 ], [ @tile_b.reload.row, @tile_b.column ]
    assert_equal [ 1, 4 ], [ @tile_c.reload.row, @tile_c.column ]
  end
end
