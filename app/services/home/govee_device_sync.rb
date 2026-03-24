module Home
  # Syncs devices from the Govee API into BearClaw's device model.
  #
  # Govee device types are mapped to BearClaw categories:
  #   Govee type 1 (light)    → category: switch  + switch capability + optional brightness sensor
  #   Govee type 2 (plug)     → category: switch  + switch capability
  #   Govee type 5 (sensor)   → category: sensor  + per-metric sensor capabilities
  #   All others              → category: custom   + status capability
  #
  # Device key format:  "govee-<mac_address>"
  # Capability key format: "capability_<instance>"  (e.g. capability_powerSwitch)
  class GoveeDeviceSync
    # Govee numeric type codes → BearClaw device category
    TYPE_MAP = {
      1 => "switch",   # lights (controllable)
      2 => "switch",   # smart plugs
      3 => "switch",   # strips
      5 => "sensor",   # temperature/humidity sensors
      6 => "switch"    # outlets
    }.freeze

    # Govee capability instances that map to BearClaw sensor metrics
    SENSOR_INSTANCE_MAP = {
      "sensorTemperature" => { metric: "temperature", unit: "C"   },
      "sensorHumidity"    => { metric: "humidity",    unit: "%RH" }
    }.freeze

    def initialize(client:, integration:)
      @client      = client
      @integration = integration
    end

    def sync!
      devices = @client.devices

      connection.update!(
        name:                "Govee",
        adapter:             "govee",
        base_url:            GoveeClient::BASE_URL,
        credential_strategy: "stored",
        status:              "online",
        last_error:          nil
      )

      seen_keys = []
      devices.each do |govee_device|
        device = upsert_device!(govee_device)
        seen_keys << device.key
      end

      # Remove devices that were not in the latest sync
      connection.devices.where.not(key: seen_keys).destroy_all
    rescue GoveeClient::Error => e
      connection.update!(
        name:                "Govee",
        adapter:             "govee",
        base_url:            GoveeClient::BASE_URL,
        credential_strategy: "stored",
        status:              "error",
        last_error:          e.message
      )
      raise
    end

    private

    # ── Device upsert ──────────────────────────────────────────────────────────

    def upsert_device!(govee_device)
      mac      = govee_device["device"].to_s
      sku      = govee_device["sku"].to_s
      raw_name = govee_device["deviceName"].presence || sku
      category = TYPE_MAP.fetch(govee_device["type"].to_i, "custom")
      cmds     = Array(govee_device["supportCmds"])

      device_key = "govee-#{mac.parameterize}"

      device = Device.find_or_initialize_by(key: device_key)
      device.service_connection = connection
      device.name               = raw_name
      device.category           = category
      device.source_kind        = "network"
      device.source_identifier  = mac
      device.status             = "available"
      device.metadata           = { "sku" => sku, "type" => govee_device["type"], "mac" => mac }
      device.save!

      upsert_capabilities!(device, category, cmds, sku, mac)

      device
    end

    def upsert_capabilities!(device, category, cmds, sku, mac)
      seen_keys = []

      if category == "switch" && cmds.include?("turn")
        key = "capability_power_switch"
        seen_keys << key
        cap                 = device.device_capabilities.find_or_initialize_by(key: key)
        cap.name            = "Power"
        cap.capability_type = "switch"
        cap.configuration   = { "sku" => sku, "device" => mac, "instance" => "powerSwitch" }
        cap.state           = { "value" => "off", "status" => "available" }
        cap.save!

        if cmds.include?("brightness")
          key = "capability_brightness"
          seen_keys << key
          cap                 = device.device_capabilities.find_or_initialize_by(key: key)
          cap.name            = "Brightness"
          cap.capability_type = "sensor"
          cap.configuration   = { "metric" => "brightness", "sku" => sku, "device" => mac }
          cap.state           = { "value" => nil, "unit" => "%", "status" => "available" }
          cap.save!
        end

      elsif category == "sensor"
        SENSOR_INSTANCE_MAP.each do |instance, meta|
          key = "capability_#{instance.underscore}"
          seen_keys << key
          cap                 = device.device_capabilities.find_or_initialize_by(key: key)
          cap.name            = meta[:metric].humanize
          cap.capability_type = "sensor"
          cap.configuration   = {
            "metric"   => meta[:metric],
            "unit"     => meta[:unit],
            "sku"      => sku,
            "device"   => mac,
            "instance" => instance
          }
          cap.state = { "value" => nil, "unit" => meta[:unit], "status" => "available" }
          cap.save!
        end
      end

      # Always add a status badge capability
      key = "capability_status"
      seen_keys << key
      cap                 = device.device_capabilities.find_or_initialize_by(key: key)
      cap.name            = "Status"
      cap.capability_type = "status"
      cap.configuration   = { "sku" => sku, "device" => mac }
      cap.state           = { "status" => "available" }
      cap.save!

      device.device_capabilities.where.not(key: seen_keys).destroy_all
    end

    # ── Backing records ────────────────────────────────────────────────────────

    def connection
      @connection ||= ServiceConnection.find_or_initialize_by(key: "govee").tap do |record|
        record.service_provider = provider
      end
    end

    def provider
      @provider ||= ServiceProvider.find_or_initialize_by(key: "govee").tap do |record|
        record.name          = "Govee"
        record.provider_type = "integration"
        record.description   = "Smart home devices — lights, plugs, and sensors from the Govee ecosystem."
        record.settings      = { "device_interfaces" => [ "network" ] }
        record.save!
      end
    end
  end
end
