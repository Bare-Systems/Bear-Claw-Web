module Home
  class DashboardLayoutSnapshotApplier
    def initialize(dashboard:, snapshot:)
      @dashboard = dashboard
      @snapshot = snapshot || {}
    end

    def apply!
      snapshot_tiles = Array(@snapshot["tiles"]).select { |entry| entry.is_a?(Hash) }
      current_tiles = @dashboard.dashboard_tiles.includes(:dashboard_widgets).index_by(&:id)
      kept_tile_ids = []

      DashboardTile.transaction do
        snapshot_tiles.sort_by { |entry| entry.fetch("position", 0).to_i }.each_with_index do |entry, index|
          tile = current_tiles[entry["tile_id"].to_i] || @dashboard.dashboard_tiles.build
          tile.assign_attributes(
            title: entry["title"].presence || tile.title,
            row: [ entry.fetch("row", 1).to_i, 1 ].max,
            column: [ entry.fetch("column", 1).to_i, 1 ].max,
            width: [ entry.fetch("width", DashboardTile::DEFAULT_SPAN).to_i, @dashboard.columns ].min,
            height: [ entry.fetch("height", DashboardTile::DEFAULT_SPAN).to_i, DashboardTile::MAX_HEIGHT ].min,
            position: index + 1,
            settings: snapshot_tile_settings(entry, tile)
          )
          tile.save!
          sync_widgets!(tile, entry.fetch("widgets", []))
          kept_tile_ids << tile.id
        end

        @dashboard.dashboard_tiles.where.not(id: kept_tile_ids).destroy_all
      end

      @dashboard.dashboard_tiles.reload
    end

    private

    def sync_widgets!(tile, widget_entries)
      tile.dashboard_widgets.destroy_all

      Array(widget_entries).each_with_index do |widget_entry, index|
        next unless widget_entry.is_a?(Hash)

        capability = DeviceCapability.find_by(id: widget_entry["device_capability_id"])
        tile.dashboard_widgets.create!(
          device_capability: capability,
          widget_type: widget_entry.fetch("widget_type"),
          title: widget_entry["title"],
          position: widget_entry.fetch("position", index + 1).to_i,
          settings: widget_entry["settings"].is_a?(Hash) ? widget_entry["settings"] : {}
        )
      end
    end

    def snapshot_tile_settings(entry, tile)
      settings = tile.settings_hash.deep_dup
      section = entry["section"].to_s.strip.presence
      section.present? ? settings.merge("section" => section) : settings.except("section")
    end
  end
end
