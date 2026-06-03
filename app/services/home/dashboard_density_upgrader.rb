module Home
  class DashboardDensityUpgrader
    TARGET_COLUMNS = 80
    DENSITY_VERSION = 3

    def initialize(dashboard:)
      @dashboard = dashboard
    end

    def upgrade!
      return @dashboard if upgraded?

      scale_factor = upgrade_scale_factor

      Dashboard.transaction do
        @dashboard.update!(
          settings: @dashboard.settings_hash.merge(
            "columns" => TARGET_COLUMNS,
            "density_version" => DENSITY_VERSION
          )
        )

        @dashboard.dashboard_tiles.order(:position, :id).find_each do |tile|
          tile.update!(
            row: ((tile.row - 1) * scale_factor) + 1,
            column: ((tile.column - 1) * scale_factor) + 1,
            width: [ tile.width * scale_factor, @dashboard.columns ].min,
            height: [ tile.height * scale_factor, DashboardTile::MAX_HEIGHT ].min
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

    def upgrade_scale_factor
      current_columns = @dashboard.columns.positive? ? @dashboard.columns : Dashboard::DEFAULT_COLUMNS
      factor = TARGET_COLUMNS / current_columns
      factor.positive? ? factor : 1
    end
  end
end
