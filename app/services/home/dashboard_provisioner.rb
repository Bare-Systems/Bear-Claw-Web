module Home
  class DashboardProvisioner
    DASHBOARD_SPECS = [
      { name: "Home Dashboard",       seed: :seed_home_dashboard!       },
      { name: "Finances Dashboard",   seed: :seed_finances_dashboard!   },
      { name: "Security Overview",    seed: :seed_security_dashboard!   }
    ].freeze

    def initialize(user:)
      @user = user
    end

    # Returns the provisioned dashboard matching the given name,
    # or nil if no dashboard with that name exists yet.
    def dashboard_named(name)
      return nil if name.blank?
      Dashboard.find_by(user: @user, context: "home", name: name)
    end

    # Returns all home dashboards for the user, ensuring each one is seeded.
    def all_dashboards
      DASHBOARD_SPECS.map do |spec|
        dashboard = Dashboard.fetch_or_create_for!(user: @user, context: :home, name: spec[:name])
        send(spec[:seed], dashboard)
        dashboard
      end
    end

    # Kept for backwards compat — callers that only want the first dashboard.
    def home_dashboard
      all_dashboards.first
    end

    private

    # ── Home Dashboard: cameras + Polar air quality ─────────────────────────

    def seed_home_dashboard!(dashboard)
      seed_camera_tiles!(dashboard)
      seed_polar_tiles!(dashboard)
    end

    def seed_camera_tiles!(dashboard)
      return unless dashboard.dashboard_tiles.empty?

      default_camera_capabilities.each_with_index do |capability, index|
        tile = dashboard.dashboard_tiles.create!(
          title:    capability.device.name,
          row:      (index / 4) + 1,
          column:   (index % 4) + 1,
          width:    1,
          height:   1,
          position: index + 1
        )
        tile.dashboard_widgets.create!(
          device_capability: capability,
          widget_type:       capability.default_widget_type,
          title:             capability.device.name,
          position:          1,
          settings:          { "refresh_interval_seconds" => 4 }
        )
      end
    end

    def default_camera_capabilities
      DeviceCapability
        .joins(:device)
        .includes(:device)
        .where(capability_type: "camera_feed", devices: { user_id: @user.id })
        .sort_by { |cap| cap.camera_id.to_s.delete_prefix("cam_").to_i }
    end

    def seed_polar_tiles!(dashboard)
      return unless dashboard.dashboard_tiles.count == 8
      return if polar_provider_widgets_exist?(dashboard)

      polar_capabilities = prioritized_polar_capabilities
      return if polar_capabilities.empty?

      start_position = dashboard.dashboard_tiles.maximum(:position).to_i
      polar_capabilities.each_with_index do |capability, index|
        tile = dashboard.dashboard_tiles.create!(
          title:    capability.name,
          row:      3 + (index / 4),
          column:   (index % 4) + 1,
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

    def polar_provider_widgets_exist?(dashboard)
      dashboard.dashboard_widgets
        .joins(device_capability: { device: { service_connection: :service_provider } })
        .where(service_providers: { key: "polar" })
        .exists?
    end

    def prioritized_polar_capabilities
      capabilities = DeviceCapability
        .joins(device: { service_connection: :service_provider })
        .includes(:device)
        .where(capability_type: "sensor", service_providers: { key: "polar" }, devices: { user_id: @user.id })

      priority = Home::PolarDeviceSync::PRIORITY_METRICS
      sorted = capabilities.sort_by do |cap|
        metric = cap.configuration_hash["metric"].to_s
        scope  = cap.device.source_identifier.to_s.end_with?(":outdoor") ? 1 : 0
        [ priority.index(metric) || priority.length, scope, cap.name ]
      end

      seen = {}
      sorted.each_with_object([]) do |cap, result|
        metric = cap.configuration_hash["metric"].to_s
        next if seen[metric]

        seen[metric] = true
        result << cap
      end
    end

    # ── Finances Dashboard: Kodiak portfolio + engine status ─────────────────

    def seed_finances_dashboard!(dashboard)
      return unless dashboard.dashboard_tiles.empty?

      portfolio_caps = kodiak_portfolio_capabilities
      engine_caps    = kodiak_engine_capabilities

      # Row 1: engine status (col 1, wide) + portfolio equity (col 2)
      # Remaining rows: other portfolio metrics 2-up
      all_caps = engine_caps + portfolio_caps
      return if all_caps.empty?

      all_caps.each_with_index do |cap, index|
        widget_type = if cap.capability_type == "status"
                        "status_badge"
                      else
                        "portfolio_stat"
                      end

        tile = dashboard.dashboard_tiles.create!(
          title:    cap.name,
          row:      (index / 4) + 1,
          column:   (index % 4) + 1,
          width:    1,
          height:   1,
          position: index + 1
        )
        tile.dashboard_widgets.create!(
          device_capability: cap,
          widget_type:       widget_type,
          title:             cap.name,
          position:          1
        )
      end
    end

    def kodiak_portfolio_capabilities
      DeviceCapability
        .joins(device: { service_connection: :service_provider })
        .includes(:device)
        .where(capability_type: "finance", service_providers: { key: "kodiak" }, devices: { user_id: @user.id })
        .order(:key)
    end

    def kodiak_engine_capabilities
      DeviceCapability
        .joins(device: { service_connection: :service_provider })
        .includes(:device)
        .where(capability_type: "status", service_providers: { key: "kodiak" }, devices: { user_id: @user.id })
    end

    # ── Security Overview Dashboard: Ursa sessions + campaigns ──────────────

    def seed_security_dashboard!(dashboard)
      return unless dashboard.dashboard_tiles.empty?

      ursa_caps = ursa_overview_capabilities
      return if ursa_caps.empty?

      ursa_caps.each_with_index do |cap, index|
        tile = dashboard.dashboard_tiles.create!(
          title:    cap.name,
          row:      (index / 4) + 1,
          column:   (index % 4) + 1,
          width:    1,
          height:   1,
          position: index + 1
        )
        tile.dashboard_widgets.create!(
          device_capability: cap,
          widget_type:       "security_stat",
          title:             cap.name,
          position:          1
        )
      end
    end

    def ursa_overview_capabilities
      DeviceCapability
        .joins(device: { service_connection: :service_provider })
        .includes(:device)
        .where(service_providers: { key: "ursa" }, devices: { user_id: @user.id })
        .order(:key)
    end
  end
end
