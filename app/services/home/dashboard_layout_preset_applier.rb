module Home
  class DashboardLayoutPresetApplier
    def initialize(dashboard:, preset:)
      @dashboard = dashboard
      @preset = preset || {}
      @columns = dashboard.columns
    end

    def apply!
      tiles = @dashboard.dashboard_tiles.order(:position, :id).to_a
      return tiles if tiles.empty?

      placements = {}
      occupied = {}
      preset_tiles = preset_tile_map

      ordered_preset_tiles(tiles, preset_tiles).each do |tile|
        snapshot = preset_tiles.fetch(tile.id)
        width = [ snapshot.fetch("width", tile.width).to_i, @columns ].min
        height = [ snapshot.fetch("height", tile.height).to_i, DashboardTile::MAX_HEIGHT ].min
        row = [ snapshot.fetch("row", tile.row).to_i, 1 ].max
        column = clamp_column(snapshot.fetch("column", tile.column).to_i, width)
        row, column = find_first_fit(occupied, width, height) unless fits?(occupied, row, column, width, height)

        place!(occupied, row, column, width, height)
        placements[tile.id] = { row: row, column: column, width: width, height: height }
      end

      tiles.each do |tile|
        next if placements.key?(tile.id)

        row, column = find_first_fit(occupied, tile.width, tile.height)
        place!(occupied, row, column, tile.width, tile.height)
        placements[tile.id] = { row: row, column: column, width: tile.width, height: tile.height }
      end

      ordered_tiles = tiles.sort_by do |tile|
        placement = placements.fetch(tile.id)
        [ placement.fetch(:row), placement.fetch(:column), tile.id ]
      end

      DashboardTile.transaction do
        ordered_tiles.each_with_index do |tile, index|
          placement = placements.fetch(tile.id)
          tile.update_columns(
            row: placement.fetch(:row),
            column: placement.fetch(:column),
            width: placement.fetch(:width),
            height: placement.fetch(:height),
            position: index + 1,
            updated_at: Time.current
          )
        end
      end

      @dashboard.dashboard_tiles.reload
    end

    private

    def preset_tile_map
      Array(@preset["tiles"]).each_with_object({}) do |entry, presets|
        next unless entry.is_a?(Hash)

        tile_id = entry["tile_id"].to_i
        next if tile_id.zero?

        presets[tile_id] = entry
      end
    end

    def ordered_preset_tiles(tiles, preset_tiles)
      tiles
        .select { |tile| preset_tiles.key?(tile.id) }
        .sort_by do |tile|
          snapshot = preset_tiles.fetch(tile.id)
          [ snapshot.fetch("position", tile.position).to_i, snapshot.fetch("row", tile.row).to_i, snapshot.fetch("column", tile.column).to_i, tile.id ]
        end
    end

    def clamp_column(column, width)
      maximum = [ @columns - width + 1, 1 ].max
      [[ column, 1 ].max, maximum].min
    end

    def find_first_fit(occupied, width, height)
      row = 1
      loop do
        1.upto([ @columns - width + 1, 1 ].max) do |column|
          return [ row, column ] if fits?(occupied, row, column, width, height)
        end
        row += 1
      end
    end

    def fits?(occupied, row, column, width, height)
      row.upto(row + height - 1) do |current_row|
        column.upto(column + width - 1) do |current_column|
          return false if occupied[[ current_row, current_column ]]
        end
      end
      true
    end

    def place!(occupied, row, column, width, height)
      row.upto(row + height - 1) do |current_row|
        column.upto(column + width - 1) do |current_column|
          occupied[[ current_row, current_column ]] = true
        end
      end
    end
  end
end
