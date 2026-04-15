module Home
  class DashboardLayoutPresetStore
    def initialize(dashboard:)
      @dashboard = dashboard
    end

    def save!(name:)
      preset_name = name.to_s.strip
      raise ActiveRecord::RecordInvalid.new(@dashboard) if preset_name.blank?

      presets = @dashboard.layout_presets.reject { |preset| preset["name"] == preset_name }
      presets << serialized_preset(preset_name)
      persist!(presets)
      fetch(name: preset_name)
    end

    def fetch(name:)
      @dashboard.layout_presets.find { |preset| preset["name"] == name.to_s.strip }
    end

    def delete!(name:)
      preset_name = name.to_s.strip
      presets = @dashboard.layout_presets.reject { |preset| preset["name"] == preset_name }
      return false if presets.size == @dashboard.layout_presets.size

      persist!(presets)
      true
    end

    private

    def serialized_preset(name)
      {
        "name" => name,
        "saved_at" => Time.current.iso8601,
        "tiles" => @dashboard.dashboard_tiles.order(:position, :id).map do |tile|
          {
            "tile_id" => tile.id,
            "row" => tile.row,
            "column" => tile.column,
            "width" => tile.width,
            "height" => tile.height,
            "position" => tile.position,
            "title" => tile.display_title,
            "section" => tile.section_name
          }
        end
      }
    end

    def persist!(presets)
      @dashboard.update!(settings: @dashboard.settings_hash.merge("layout_presets" => presets.sort_by { |preset| preset["name"].to_s.downcase }))
      @dashboard.reload
    end
  end
end
