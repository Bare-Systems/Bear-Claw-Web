module Home
  class DashboardProvisioner
    def initialize(user:)
      @user = user
    end

    def home_dashboard
      dashboard = Dashboard.fetch_or_create_for!(user: @user, context: :home, name: "Home Dashboard")
      seed_default_layout!(dashboard)
      seed_default_polar_tiles!(dashboard)
      dashboard
    end

    private

    def seed_default_layout!(dashboard)
      return unless dashboard.dashboard_tiles.empty?

      default_camera_capabilities.each_with_index do |capability, index|
        tile = dashboard.dashboard_tiles.create!(
          title: capability.device.name,
          row: (index / 4) + 1,
          column: (index % 4) + 1,
          width: 1,
          height: 1,
          position: index + 1
        )

        tile.dashboard_widgets.create!(
          device_capability: capability,
          widget_type: capability.default_widget_type,
          title: capability.device.name,
          position: 1,
          settings: { "refresh_interval_seconds" => 4 }
        )
      end
    end

    def default_camera_capabilities
      DeviceCapability
        .joins(:device)
        .includes(:device)
        .where(capability_type: "camera_feed", devices: { user_id: @user.id })
        .sort_by { |capability| capability.camera_id.to_s.delete_prefix("cam_").to_i }
    end

    def seed_default_polar_tiles!(dashboard)
      return unless dashboard.dashboard_tiles.count == 8
      return if dashboard.dashboard_widgets.joins(device_capability: { device: { service_connection: :service_provider } }).where(service_providers: { key: "polar" }).exists?

      polar_capabilities = prioritized_polar_capabilities
      return if polar_capabilities.empty?

      # Lay air quality tiles in row(s) after the 8 camera tiles, 4 per row.
      start_position = dashboard.dashboard_tiles.maximum(:position).to_i
      polar_capabilities.each_with_index do |capability, index|
        row    = 3 + (index / 4)
        column = (index % 4) + 1

        tile = dashboard.dashboard_tiles.create!(
          title:    capability.name,
          row:      row,
          column:   column,
          width:    1,
          height:   1,
          position: start_position + index + 1
        )
        tile.dashboard_widgets.create!(
          device_capability: capability,
          widget_type:       "air_quality_stat",
          title:             capability.name,
          position:          1
        )
      end
    end

    # All indoor Polar sensor capabilities ordered by PRIORITY_METRICS.
    # Falls back to outdoor when no indoor reading exists for a given metric.
    # De-duplicates so each metric appears at most once.
    def prioritized_polar_capabilities
      capabilities = DeviceCapability.joins(device: { service_connection: :service_provider })
        .includes(:device)
        .where(capability_type: "sensor", service_providers: { key: "polar" }, devices: { user_id: @user.id })

      priority = Home::PolarDeviceSync::PRIORITY_METRICS
      sorted = capabilities.sort_by do |cap|
        metric = cap.configuration_hash["metric"].to_s
        scope  = cap.device.source_identifier.to_s.end_with?(":outdoor") ? 1 : 0
        [ priority.index(metric) || priority.length, scope, cap.name ]
      end

      # Keep the best (indoor-preferring) entry per metric
      seen = {}
      sorted.each_with_object([]) do |cap, result|
        metric = cap.configuration_hash["metric"].to_s
        next if seen[metric]

        seen[metric] = true
        result << cap
      end
    end
  end
end
