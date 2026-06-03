module HomeHelper
  DASHBOARD_DEFAULT_SECTIONS = [ "General", "Cameras", "Security", "Air", "Trading", "Operations" ].freeze
  DASHBOARD_HEALTH_THRESHOLDS = {
    "camera_feed" => 45.seconds,
    "status_badge" => 10.minutes,
    "switch_control" => 10.minutes,
    "sensor_stat" => 15.minutes,
    "air_quality_stat" => 15.minutes,
    "portfolio_stat" => 10.minutes,
    "security_stat" => 10.minutes
  }.freeze

  DASHBOARD_HEALTH_SEVERITY = {
    healthy: 0,
    unknown: 1,
    stale: 2,
    offline: 3
  }.freeze

  DASHBOARD_ALERT_SEVERITY = {
    offline: 0,
    error: 1,
    stale: 2
  }.freeze

  DASHBOARD_OFFLINE_STATUSES = %w[offline error dead blocked unavailable].freeze
  DASHBOARD_STALE_STATUSES = %w[stale degraded warning pending].freeze

  def dashboard_tile_style(tile)
    [
      "--tile-column: #{tile.column}",
      "--tile-row: #{tile.row}",
      "--tile-width: #{tile.width}",
      "--tile-height: #{tile.height}",
      "--tile-mobile-span: #{dashboard_tile_mobile_span(tile)}",
      "--tile-mobile-height: #{dashboard_tile_mobile_height(tile)}",
      "grid-column: var(--tile-column) / span var(--tile-width)",
      "grid-row: var(--tile-row) / span var(--tile-height)"
    ].join("; ")
  end

  def dashboard_row_unit_rem(dashboard)
    dashboard.row_unit_rem
  end

  def dashboard_tile_mobile_span(tile)
    return 2 if tile.width >= tile.dashboard.default_tile_span(base_span: 4)
    return 2 if tile.dashboard_widgets.any? { |widget| widget.widget_type == "camera_feed" }

    1
  end

  def dashboard_tile_mobile_height(tile)
    max_height = tile.dashboard_widgets.any? { |widget| widget.widget_type == "camera_feed" } ? 3 : 2
    tile.height.clamp(1, max_height)
  end

  def dashboard_tile_body_classes(tile)
    if dashboard_tile_chrome_free?(tile)
      "flex min-h-0 flex-1 flex-col"
    else
      "flex-1 space-y-3 p-3 sm:p-4"
    end
  end

  def dashboard_tile_chrome_free?(tile)
    return false unless tile.dashboard_widgets.size == 1

    %w[camera_feed air_quality_stat].include?(tile.dashboard_widgets.first.widget_type)
  end

  def dashboard_tile_full_bleed_camera?(tile)
    dashboard_tile_chrome_free?(tile) && tile.dashboard_widgets.first.widget_type == "camera_feed"
  end

  def dashboard_tile_chrome_free_air_quality?(tile)
    dashboard_tile_chrome_free?(tile) && tile.dashboard_widgets.first.widget_type == "air_quality_stat"
  end

  def dashboard_section_options(dashboard)
    (DASHBOARD_DEFAULT_SECTIONS + dashboard.dashboard_tiles.map(&:section_name)).uniq.sort
  end

  def dashboard_connection_status_label(connection)
    connection&.status.presence || "unknown"
  end

  def dashboard_capability_label(capability)
    [ capability.service_provider&.name, capability.device.name, capability.name ].compact.join(" · ")
  end

  def dashboard_capability_picker_data(capability)
    {
      id: capability.id,
      label: dashboard_capability_label(capability),
      provider_name: capability.service_provider&.name.presence || "Unknown provider",
      device_name: capability.device.name,
      capability_name: capability.name,
      capability_type: capability.capability_type,
      capability_type_label: capability.capability_type.humanize,
      source_label: capability.device.source_label,
      allowed_widget_types: capability.allowed_widget_types,
      default_widget_type: capability.default_widget_type,
      default_widget_label: dashboard_widget_type_label(capability.default_widget_type),
      search_text: [
        capability.service_provider&.name,
        capability.device.name,
        capability.name,
        capability.capability_type
      ].compact.join(" ").downcase
    }
  end

  def dashboard_capability_provider_options(capabilities)
    capabilities
      .map { |capability| capability.service_provider&.name.presence }
      .compact
      .uniq
      .sort
      .map { |name| [ name, name ] }
  end

  def provider_type_options
    ServiceProvider::PROVIDER_TYPES.map { |type| [ type.humanize, type ] }
  end

  def connection_adapter_options
    ServiceConnection::ADAPTERS.map { |adapter| [ adapter.humanize, adapter ] }
  end

  def connection_status_options
    ServiceConnection::STATUSES.map { |status| [ status.humanize, status ] }
  end

  def device_category_options
    Device::CATEGORIES.map { |category| [ category.humanize, category ] }
  end

  def device_source_kind_options
    Device::SOURCE_KINDS.map { |kind| [ kind.humanize, kind ] }
  end

  def device_status_options
    Device::STATUSES.map { |status| [ status.humanize, status ] }
  end

  def capability_type_options
    DeviceCapability::CAPABILITY_TYPES.map { |type| [ type.humanize, type ] }
  end

  def provider_summary(provider)
    "#{provider.provider_type.humanize} · #{pluralize(provider.service_connections.size, "connection")}"
  end

  def device_location(device)
    device.metadata_hash["location"].presence || "unassigned"
  end

  def dashboard_widget_type_options(capability = nil)
    capability_type = capability&.capability_type
    Home::CapabilityWidgetCatalog.options_for_select(capability_type)
  end

  def dashboard_widget_type_label(widget_type)
    {
      "camera_feed" => "Live Camera Feed",
      "status_badge" => "Status Badge",
      "switch_control" => "Switch Control",
      "sensor_stat" => "Sensor Reading",
      "air_quality_stat" => "Air Quality Card",
      "portfolio_stat" => "Portfolio Value",
      "security_stat" => "Security Counter"
    }.fetch(widget_type.to_s, widget_type.to_s.humanize)
  end

  def dashboard_widget_type_labels
    DashboardWidget::WIDGET_TYPES.each_with_object({}) do |widget_type, labels|
      labels[widget_type] = dashboard_widget_type_label(widget_type)
    end
  end

  def dashboard_widget_partial(widget)
    case widget.widget_type
    when "camera_feed"      then "home/widgets/camera_feed"
    when "sensor_stat"      then "home/widgets/sensor_stat"
    when "air_quality_stat" then "home/widgets/air_quality_stat"
    when "switch_control"   then "home/widgets/switch_control"
    when "portfolio_stat"   then "home/widgets/portfolio_stat"
    when "security_stat"    then "home/widgets/security_stat"
    else                         "home/widgets/status_badge"
    end
  end

  def dashboard_quick_add_packs(capabilities)
    Home::DashboardQuickAddPackCatalog.new(capabilities: capabilities).available_packs
  end

  # Server-side seed for a camera tile's feed aspect ratio (width / height).
  # The camera-feed Stimulus controller refines this with the frame's real
  # natural dimensions once the first snapshot loads; until then this default
  # gives the resize handle a sane shape to lock against. 16:9 covers the common
  # Koala camera output.
  def dashboard_camera_widget_aspect(tile)
    widget = tile.dashboard_widgets.detect { |w| w.widget_type == "camera_feed" }
    stored = widget&.settings_hash&.dig("feed_aspect").to_f
    stored.positive? ? stored.round(4) : (16.0 / 9.0).round(4)
  end

  def dashboard_camera_refresh_interval_seconds(widget)
    interval = widget.refresh_interval_seconds

    # Existing dashboard camera tiles were provisioned at 4s, which feels too
    # sluggish for a "live" wall. Nudge that legacy default to 2s while still
    # honoring any explicit faster/slower per-widget override.
    return 2 if widget.widget_type == "camera_feed" && interval == 4

    interval
  end

  def dashboard_layout_preset_saved_at(preset)
    timestamp = preset["saved_at"].presence
    return "unsaved" if timestamp.blank?

    parsed = Time.zone.parse(timestamp.to_s)
    parsed ? parsed.strftime("%Y-%m-%d %H:%M") : timestamp.to_s
  rescue ArgumentError, TypeError
    timestamp.to_s
  end

  def dashboard_layout_history_recorded_at(entry)
    timestamp = entry["recorded_at"].presence
    return "unknown time" if timestamp.blank?

    parsed = Time.zone.parse(timestamp.to_s)
    parsed ? parsed.strftime("%Y-%m-%d %H:%M") : timestamp.to_s
  rescue ArgumentError, TypeError
    timestamp.to_s
  end

  def dashboard_widget_observed_at(widget)
    capability = widget.device_capability
    return nil if capability.blank?

    state = capability.state_hash
    dashboard_parse_observed_at(state["last_seen_at"].presence || state["last_probed_at"].presence)
  end

  def dashboard_widget_health_state(widget)
    capability = widget.device_capability
    return :unknown if capability.blank?

    status = capability.status_label.to_s.downcase
    return :offline if DASHBOARD_OFFLINE_STATUSES.include?(status)
    return :stale if DASHBOARD_STALE_STATUSES.include?(status)

    # Camera feeds are health-checked by frame capture, not scene activity. A
    # quiet scene (no person/package) is NOT stale — only a real capture failure
    # (status unavailable/degraded, handled above) counts. Detection events are
    # surfaced separately via Koala alerts, not via widget freshness.
    return :healthy if widget.widget_type == "camera_feed"

    observed_at = dashboard_widget_observed_at(widget)
    return :unknown if observed_at.blank?

    observed_at < Time.current - dashboard_widget_stale_after(widget) ? :stale : :healthy
  end

  def dashboard_widget_health_label(widget)
    dashboard_health_label_for_state(dashboard_widget_health_state(widget))
  end

  def dashboard_widget_health_detail(widget)
    capability = widget.device_capability
    return "Awaiting first sync" if capability.blank?

    state = dashboard_widget_health_state(widget)
    observed_at = dashboard_widget_observed_at(widget)

    case state
    when :offline
      capability.state_hash["last_error"].presence || "Connection unavailable"
    when :stale
      observed_at.present? ? "Last update #{time_ago_in_words(observed_at)} ago" : "Awaiting fresh data"
    when :healthy
      observed_at.present? ? "Updated #{time_ago_in_words(observed_at)} ago" : "Fresh"
    else
      "Awaiting first sync"
    end
  end

  def dashboard_tile_health_state(tile)
    states = tile.dashboard_widgets.map { |widget| dashboard_widget_health_state(widget) }
    return :unknown if states.empty?

    states.max_by { |state| DASHBOARD_HEALTH_SEVERITY.fetch(state, -1) }
  end

  def dashboard_tile_health_label(tile)
    dashboard_health_label_for_state(dashboard_tile_health_state(tile))
  end

  def dashboard_alerts_for_tiles(tiles, limit: 6)
    Array(tiles)
      .flat_map do |tile|
        tile.dashboard_widgets.filter_map do |widget|
          alert_state = dashboard_widget_alert_state(widget)
          next if alert_state.blank?

          {
            tile: tile,
            widget: widget,
            alert_state: alert_state,
            label: dashboard_alert_label_for_state(alert_state),
            detail: dashboard_alert_detail(widget, alert_state),
            section_name: tile.section_name
          }
        end
      end
      .sort_by do |alert|
        [
          DASHBOARD_ALERT_SEVERITY.fetch(alert[:alert_state], 99),
          alert[:tile].position,
          alert[:widget].position
        ]
      end
      .first(limit)
  end

  def dashboard_widget_alert_state(widget)
    health_state = dashboard_widget_health_state(widget)
    capability = widget.device_capability
    last_error = capability&.state_hash&.[]("last_error").presence

    return :offline if health_state == :offline
    return :error if last_error.present?
    return :stale if health_state == :stale

    nil
  end

  def dashboard_alert_label_for_state(state)
    case state.to_sym
    when :offline then "Offline"
    when :error then "Error"
    else "Stale"
    end
  end

  def dashboard_alert_detail(widget, alert_state = dashboard_widget_alert_state(widget))
    capability = widget.device_capability
    return dashboard_widget_health_detail(widget) if capability.blank?

    return capability.state_hash["last_error"] if alert_state.to_sym == :error

    dashboard_widget_health_detail(widget)
  end

  def dashboard_alert_badge_classes(state)
    case state.to_sym
    when :offline
      "border-red-700/70 bg-red-950/70 text-red-200"
    when :error
      "border-amber-700/70 bg-amber-950/70 text-amber-200"
    else
      "border-yellow-700/70 bg-yellow-950/70 text-yellow-200"
    end
  end

  def dashboard_health_badge_classes(state)
    ursa_status_classes(
      case state.to_sym
      when :healthy then "active"
      when :stale then "stale"
      when :offline then "dead"
      else "unknown"
      end
    )
  end

  def switch_state_label(capability)
    capability.switch_on? ? "On" : "Off"
  end

  # Detection alerts (person/package) sourced from Koala's /admin/alerts.
  def koala_alert_headline(alert)
    label = alert["label"].to_s
    noun = label.presence&.humanize || "Motion"
    "#{noun} detected"
  end

  def koala_alert_meta(alert)
    parts = []
    zone = alert["zone_id"].to_s
    parts << zone.humanize if zone.present?
    parts << alert["camera_id"] if alert["camera_id"].present?
    if (confidence = alert["confidence"]).present?
      parts << "#{(confidence.to_f * 100).round}%"
    end
    parts.join(" · ")
  end

  def koala_alert_time(alert)
    observed = dashboard_parse_observed_at(alert["observed_at"])
    return "just now" if observed.blank?

    "#{time_ago_in_words(observed)} ago"
  end

  def koala_alert_badge_classes(alert)
    case alert["label"].to_s
    when "person"
      "border-sky-700/70 bg-sky-950/70 text-sky-200"
    when "package"
      "border-emerald-700/70 bg-emerald-950/70 text-emerald-200"
    else
      "border-gray-700/70 bg-gray-950/70 text-gray-200"
    end
  end

  private

  def dashboard_widget_stale_after(widget)
    DASHBOARD_HEALTH_THRESHOLDS.fetch(widget.widget_type, 15.minutes)
  end

  def dashboard_health_label_for_state(state)
    case state.to_sym
    when :healthy then "Fresh"
    when :stale then "Stale"
    when :offline then "Offline"
    else "Awaiting sync"
    end
  end

  def dashboard_parse_observed_at(value)
    return nil if value.blank?

    value.is_a?(Numeric) ? Time.zone.at(value) : Time.zone.parse(value.to_s)
  rescue ArgumentError, TypeError
    nil
  end
end
