module Home
  class DashboardLayoutNormalizer
    def initialize(dashboard:)
      @dashboard = dashboard
      @columns = dashboard.columns
    end

    def normalize!(anchor_tile: nil)
      tiles = @dashboard.dashboard_tiles.order(:position, :id).to_a
      return tiles if tiles.empty?

      placements = {}
      occupied = {}

      if anchor_tile.present?
        anchor_tile.column = clamp_column(anchor_tile.column, anchor_tile.width)
        anchor_tile.row = [ anchor_tile.row.to_i, 1 ].max
        place!(occupied, anchor_tile.row, anchor_tile.column, anchor_tile.width, anchor_tile.height)
        placements[anchor_tile.id] = [ anchor_tile.row, anchor_tile.column ]
      end

      tiles.each do |tile|
        next if anchor_tile && tile.id == anchor_tile.id

        row, column = find_first_fit(occupied, tile.width, tile.height)
        place!(occupied, row, column, tile.width, tile.height)
        placements[tile.id] = [ row, column ]
      end

      ordered_tiles = tiles.sort_by do |tile|
        row, column = placements.fetch(tile.id)
        [ row, column, tile.id ]
      end

      DashboardTile.transaction do
        ordered_tiles.each_with_index do |tile, index|
          row, column = placements.fetch(tile.id)
          tile.update_columns(
            row: row,
            column: column,
            position: index + 1,
            updated_at: Time.current
          )
        end
      end

      @dashboard.dashboard_tiles.reload
    end

    private

    def clamp_column(column, width)
      minimum = 1
      maximum = [ @columns - width + 1, 1 ].max
      [[ column.to_i, minimum ].max, maximum].min
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
