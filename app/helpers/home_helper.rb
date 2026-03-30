module HomeHelper
  def dashboard_tile_style(tile)
    "grid-column: #{tile.column} / span #{tile.width}; grid-row: #{tile.row} / span #{tile.height};"
  end

  def dashboard_connection_status_label(connection)
    connection&.status.presence || "unknown"
  end

  def dashboard_capability_label(capability)
    "#{capability.device.name} · #{capability.name}"
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

  def switch_state_label(capability)
    capability.switch_on? ? "On" : "Off"
  end
end
