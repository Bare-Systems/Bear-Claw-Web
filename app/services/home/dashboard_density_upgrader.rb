module Home
  class DashboardDensityUpgrader
    TARGET_COLUMNS = 8
    DENSITY_VERSION = 2
    SCALE_FACTOR = 2

    def initialize(dashboard:)
      @dashboard = dashboard
    end

    def upgrade!
      return @dashboard if upgraded?

      Dashboard.transaction do
        @dashboard.update!(
          settings: @dashboard.settings_hash.merge(
            "columns" => TARGET_COLUMNS,
            "density_version" => DENSITY_VERSION
          )
        )

        @dashboard.dashboard_tiles.order(:position, :id).find_each do |tile|
          tile.update!(
            row: ((tile.row - 1) * SCALE_FACTOR) + 1,
            column: ((tile.column - 1) * SCALE_FACTOR) + 1,
            width: [ tile.width * SCALE_FACTOR, @dashboard.columns ].min,
            height: [ tile.height * SCALE_FACTOR, DashboardTile::MAX_HEIGHT ].min
          )
        end

        Home::DashboardLayoutNormalizer.new(dashboard: @dashboard).normalize!
      end

      @dashboard.reload
    end

    private

    def upgraded?
      @dashboard.settings_hash["density_version"].to_i >= DENSITY_VERSION || @dashboard.columns >= TARGET_COLUMNS
    end
  end
end
