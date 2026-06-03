module Home
  # One-time correction of camera-feed tile heights.
  #
  # Camera tiles created before the square-cell grid fix stored heights that made
  # the tile far taller than the feed, so 16:9 frames letterboxed with large black
  # bars. With square grid cells a tile's pixel aspect equals width:height, so the
  # feed-shaped height is `width / feed_aspect`. This backfill snaps each existing
  # camera tile to that height exactly once (guarded by a settings version), then
  # re-packs the layout. Manual resizes afterwards are preserved because it never
  # runs again.
  class CameraAspectBackfill
    VERSION = 1

    def initialize(dashboard:)
      @dashboard = dashboard
    end

    def run!
      return @dashboard if @dashboard.settings_hash["camera_aspect_version"].to_i >= VERSION

      Dashboard.transaction do
        changed = false

        @dashboard.dashboard_tiles.includes(:dashboard_widgets).each do |tile|
          next unless camera_tile?(tile)

          target = @dashboard.camera_height_for_width(tile.width)
          next if tile.height == target

          tile.update!(height: target)
          changed = true
        end

        @dashboard.update!(
          settings: @dashboard.settings_hash.merge("camera_aspect_version" => VERSION)
        )

        Home::DashboardLayoutNormalizer.new(dashboard: @dashboard).normalize! if changed
      end

      @dashboard.reload
    end

    private

    def camera_tile?(tile)
      tile.dashboard_widgets.size == 1 &&
        tile.dashboard_widgets.first.widget_type == "camera_feed"
    end
  end
end
