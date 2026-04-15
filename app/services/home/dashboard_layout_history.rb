module Home
  class DashboardLayoutHistory
    MAX_ENTRIES = 12

    def initialize(dashboard:)
      @dashboard = dashboard
    end

    def entries
      history = @dashboard.settings_hash["layout_history"]
      history.is_a?(Array) ? history.select { |entry| entry.is_a?(Hash) } : []
    end

    def snapshot(label:)
      {
        "label" => label.to_s,
        "recorded_at" => Time.current.iso8601,
        "tiles" => @dashboard.dashboard_tiles.order(:position, :id).map do |tile|
          {
            "tile_id" => tile.id,
            "title" => tile.title,
            "row" => tile.row,
            "column" => tile.column,
            "width" => tile.width,
            "height" => tile.height,
            "position" => tile.position,
            "section" => tile.section_name,
            "widgets" => tile.dashboard_widgets.order(:position, :id).map do |widget|
              {
                "device_capability_id" => widget.device_capability_id,
                "widget_type" => widget.widget_type,
                "title" => widget.title,
                "position" => widget.position,
                "settings" => widget.settings_hash
              }
            end
          }
        end
      }
    end

    def record!(label:)
      push!(snapshot: snapshot(label: label))
    end

    def push!(snapshot:)
      updated = entries.last(MAX_ENTRIES - 1) + [ snapshot ]
      persist!(updated)
      snapshot
    end

    def undo!
      latest = entries.last
      return nil if latest.blank?

      Home::DashboardLayoutSnapshotApplier.new(dashboard: @dashboard, snapshot: latest).apply!
      persist!(entries[0...-1])
      latest
    end

    private

    def persist!(history_entries)
      @dashboard.update!(settings: @dashboard.settings_hash.merge("layout_history" => history_entries))
      @dashboard.reload
    end
  end
end
