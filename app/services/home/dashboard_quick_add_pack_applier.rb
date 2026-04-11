module Home
  class DashboardQuickAddPackApplier
    Result = Struct.new(:created_tiles, :skipped_items, keyword_init: true) do
      def created_count
        created_tiles.size
      end
    end

    def initialize(dashboard:, pack:)
      @dashboard = dashboard
      @pack = pack
    end

    def apply!
      created_tiles = []
      skipped_items = []
      position = @dashboard.dashboard_tiles.maximum(:position).to_i

      Dashboard.transaction do
        @pack.items.each do |item|
          if widget_exists_for?(item)
            skipped_items << item
            next
          end

          position += 1
          tile = @dashboard.dashboard_tiles.create!(
            title: item.title,
            row: 1,
            column: 1,
            width: item.width,
            height: item.height,
            position: position
          )
          tile.dashboard_widgets.create!(
            device_capability: item.capability,
            widget_type: item.widget_type,
            title: item.title,
            position: 1,
            settings: item.settings
          )
          created_tiles << tile
        end

        if created_tiles.any?
          Home::DashboardLayoutNormalizer.new(dashboard: @dashboard).normalize!
        end
      end

      Result.new(created_tiles: created_tiles, skipped_items: skipped_items)
    end

    private

    def widget_exists_for?(item)
      @dashboard.dashboard_widgets.exists?(device_capability_id: item.capability.id, widget_type: item.widget_type)
    end
  end
end
