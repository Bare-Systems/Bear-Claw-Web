module Home
  class PolarDeviceSync
    PRIORITY_METRICS = %w[temperature humidity co2 voc radon pm2.5].freeze

    def initialize(client:, base_url:, user: nil)
      @client   = client
      @base_url = base_url.to_s.strip
      @user     = user
    end

    def sync!
      readings = @client.latest_readings   # flat array from /v1/readings/latest
      health   = @client.station_health    # { station_id:, overall:, components:, generated_at: }

      connection.update!(
        name:                "Polar",
        adapter:             "polar",
        base_url:            @base_url,
        credential_strategy: "environment",
        status:              normalize_connection_status(health["overall"]),
        last_error:          nil
      )

      station = upsert_inventory!(readings, health)

      # Outdoor environmental feeds (NOAA weather + AirNow air quality) live on
      # separate endpoints and are best-effort: a missing token or a stale feed
      # must not fail the indoor-sensor sync above.
      sync_outdoor!(station)

      station
    rescue PolarClient::Error => e
      connection.update!(
        name:                "Polar",
        adapter:             "polar",
        base_url:            @base_url,
        credential_strategy: "environment",
        status:              "error",
        last_error:          e.message
      )
      raise
    end

    private

    # ── Inventory ──────────────────────────────────────────────────────────────

    def upsert_inventory!(readings, health)
      station_id = health["station_id"].presence || "polar-station"
      station    = upsert_station_device!(station_id, health)

      # Group readings by sensor_id — each physical sensor becomes one Device.
      by_sensor = Array(readings).group_by { |r| r["sensor_id"].to_s.presence || "default" }

      by_sensor.each do |sensor_id, sensor_readings|
        upsert_sensor_device!(
          station:        station,
          station_id:     station_id,
          sensor_id:      sensor_id,
          readings:       sensor_readings,
          health_overall: health["overall"]
        )
      end

      station
    end

    # ── Outdoor feeds (NOAA weather + AirNow air quality) ───────────────────────

    def sync_outdoor!(station)
      upsert_weather_device!(station, @client.weather_current)
    rescue PolarClient::Error => e
      Rails.logger.warn("[PolarDeviceSync] weather sync skipped: #{e.message}")
    ensure
      begin
        upsert_air_quality_device!(station, @client.air_quality_current)
      rescue PolarClient::Error => e
        Rails.logger.warn("[PolarDeviceSync] air quality sync skipped: #{e.message}")
      end
    end

    # Outdoor weather → one Device with temperature/humidity/wind/pressure metrics.
    def upsert_weather_device!(station, weather)
      return if weather.blank?

      target_id   = weather["target_id"].presence || "polar"
      stale       = weather["stale"]
      recorded_at = weather["recorded_at"]
      quality     = stale ? "unavailable" : (weather["quality"].presence || "good")
      status      = stale ? "degraded" : "available"
      source      = weather["source"].presence || "noaa"

      device = Device.find_or_initialize_by(key: "polar-weather-#{target_id}")
      device.user ||= @user
      device.service_connection = connection
      device.parent_device      = station if station
      device.name               = "Outdoor Weather"
      device.category           = "sensor"
      device.source_kind        = "network"
      device.source_identifier  = "#{target_id}:weather"
      device.status             = status
      device.metadata           = {
        "scope"          => "outdoor",
        "source"         => source,
        "source_station" => weather["source_station"],
        "condition"      => weather["condition"]
      }.compact
      device.save!

      seen = []
      [
        { metric: "condition",   name: "Condition",  value: nil,                   unit: "",    display: weather["condition"] },
        { metric: "temperature", name: "Temperature", value: weather["temperature_c"], unit: "°C" },
        { metric: "humidity",    name: "Humidity",    value: weather["humidity_pct"],  unit: "%" },
        { metric: "wind_speed",  name: "Wind Speed",  value: weather["wind_speed_ms"], unit: "m/s" },
        { metric: "pressure",    name: "Pressure",    value: weather["pressure_hpa"],  unit: "hPa" }
      ].each do |m|
        next if m[:value].nil? && m[:display].to_s.strip.empty?

        seen << upsert_outdoor_metric!(
          device:      device,
          metric:      m[:metric],
          name:        m[:name],
          value:       m[:value],
          unit:        m[:unit],
          display:     m[:display],
          source:      source,
          quality:     quality,
          status:      status,
          recorded_at: recorded_at
        )
      end

      device.device_capabilities.where(capability_type: "sensor").where.not(key: seen).destroy_all
      device
    end

    # Outdoor air quality → one Device with an overall AQI metric plus per-pollutant
    # metrics (PM2.5, ozone, etc.) when AirNow reports them.
    def upsert_air_quality_device!(station, aq)
      return if aq.blank?

      target_id   = aq["target_id"].presence || "polar"
      stale       = aq["stale"]
      recorded_at = aq["recorded_at"]
      quality     = stale ? "unavailable" : "good"
      status      = stale ? "degraded" : "available"
      source      = aq["source"].presence || "airnow"

      device = Device.find_or_initialize_by(key: "polar-air-quality-#{target_id}")
      device.user ||= @user
      device.service_connection = connection
      device.parent_device      = station if station
      device.name               = "Outdoor Air Quality"
      device.category           = "sensor"
      device.source_kind        = "network"
      device.source_identifier  = "#{target_id}:air-quality"
      device.status             = status
      device.metadata           = {
        "scope"          => "outdoor",
        "source"         => source,
        "category"       => aq["category"],
        "reporting_area" => aq["reporting_area"],
        "stale_reason"   => aq["stale_reason"],
        # AirNow reports per-pollutant AQI sub-indices (no raw concentrations),
        # so we keep them here for reference rather than as gauge capabilities
        # that would mis-render against concentration thresholds.
        "pollutants"     => Array(aq["pollutants"]).map { |p|
          { "code" => p["code"], "name" => p["name"], "aqi" => p["aqi"],
            "category" => p["category"], "primary" => p["primary"] }.compact
        }
      }.compact
      device.save!

      seen = [
        upsert_outdoor_metric!(
          device:      device,
          metric:      "aqi",
          name:        "Air Quality Index",
          value:       aq["overall_aqi"],
          unit:        "AQI",
          # Leave display nil so the numeric AQI is the headline; the EPA
          # category ("Good"/"Moderate"/…) already shows via the band badge.
          display:     nil,
          source:      source,
          quality:     quality,
          status:      status,
          recorded_at: recorded_at
        )
      ]

      device.device_capabilities.where(capability_type: "sensor").where.not(key: seen).destroy_all
      device
    end

    # Shared writer for an outdoor metric capability, mirroring the indoor schema
    # so Home::MetricPresenter renders both identically.
    def upsert_outdoor_metric!(device:, metric:, name:, value:, unit:, display:, source:, quality:, status:, recorded_at:)
      key = "metric_#{metric.to_s.parameterize(separator: '_')}"

      capability                 = device.device_capabilities.find_or_initialize_by(key: key)
      capability.name            = name
      capability.capability_type = "sensor"
      capability.configuration   = {
        "metric" => metric,
        "source" => source,
        "scope"  => "outdoor"
      }.compact
      capability.state = {
        "value"           => value,
        "display_value"   => display.presence,
        "unit"            => unit.presence,
        "quality"         => quality,
        "status"          => status,
        "last_seen_at"    => recorded_at,
        "selected_source" => source
      }.compact
      capability.save!

      key
    end

    # Creates/updates the logical Polar station as the parent Device.
    def upsert_station_device!(station_id, health)
      device = Device.find_or_initialize_by(key: "polar-station-#{station_id}")
      device.user ||= @user
      device.service_connection = connection
      device.name               = "Polar Station"
      device.category           = "network_service"
      device.source_kind        = "network"
      device.source_identifier  = station_id
      device.status             = normalize_device_status(health["overall"])
      device.metadata           = {
        "generated_at" => health["generated_at"],
        "components"   => health["components"] || []
      }
      device.save!

      capability                 = device.device_capabilities.find_or_initialize_by(key: "station_health")
      capability.name            = "Station Health"
      capability.capability_type = "status"
      capability.configuration   = { "service" => "polar", "station_id" => station_id }
      capability.state           = {
        "status"          => health["overall"],
        "generated_at"    => health["generated_at"],
        "component_count" => Array(health["components"]).size
      }
      capability.save!

      device
    end

    # Creates/updates one physical sensor device and its per-metric capabilities.
    def upsert_sensor_device!(station:, station_id:, sensor_id:, readings:, health_overall:)
      # Use the source field of the first reading as a human-readable device name.
      source_label = readings.first&.dig("source").to_s.presence || sensor_id

      device = Device.find_or_initialize_by(key: "polar-#{station_id}-#{sensor_id}")
      device.user ||= @user
      device.service_connection = connection
      device.parent_device      = station
      device.name               = source_label.humanize
      device.category           = "sensor"
      device.source_kind        = "network"
      device.source_identifier  = "#{station_id}:#{sensor_id}"
      device.status             = normalize_device_status(health_overall)
      device.metadata           = { "sensor_id" => sensor_id, "source" => source_label }
      device.save!

      seen_keys = []
      sorted_readings(readings).each do |reading|
        key = metric_key(reading)
        seen_keys << key

        capability                 = device.device_capabilities.find_or_initialize_by(key: key)
        capability.name            = reading["metric"].to_s.humanize
        capability.capability_type = "sensor"
        capability.configuration   = {
          "metric" => reading["metric"],
          "source" => reading["source"],
          "scope"  => "indoor"
        }.compact
        capability.state = {
          "value"           => reading["value"],
          "unit"            => reading["unit"],
          "quality"         => reading["quality_flag"],
          "status"          => normalize_metric_status(reading["quality_flag"], health_overall),
          "last_seen_at"    => reading["recorded_at"],
          "selected_source" => reading["source"]
        }.compact
        capability.save!
      end

      # Remove capabilities for metrics that no longer appear in the feed.
      device.device_capabilities.where(capability_type: "sensor").where.not(key: seen_keys).destroy_all

      device
    end

    # ── Helpers ────────────────────────────────────────────────────────────────

    def sorted_readings(readings)
      Array(readings).sort_by do |r|
        metric_name = r["metric"].to_s
        priority    = PRIORITY_METRICS.index(metric_name) || PRIORITY_METRICS.length
        [ priority, metric_name ]
      end
    end

    def metric_key(reading)
      "metric_#{reading['metric'].to_s.parameterize(separator: '_')}"
    end

    def normalize_metric_status(quality_flag, fallback_status)
      case quality_flag.to_s
      when "good"                  then "available"
      when "estimated", "outlier"  then "degraded"
      when "unavailable"           then "unavailable"
      else                              normalize_device_status(fallback_status)
      end
    end

    def normalize_connection_status(status)
      case status.to_s
      when "ok", "healthy", "available", "ready"        then "online"
      when "degraded", "stale", "warning"               then "degraded"
      when "error", "failed", "offline", "unavailable"  then "error"
      else "unknown"
      end
    end

    def normalize_device_status(status)
      case status.to_s
      when "ok", "healthy", "available", "ready"        then "available"
      when "degraded", "stale", "warning"               then "degraded"
      when "error", "failed", "offline", "unavailable"  then "unavailable"
      else "unknown"
      end
    end

    def connection
      @connection ||= ServiceConnection.find_or_initialize_by(key: "polar").tap do |record|
        record.service_provider = provider
      end
    end

    def provider
      @provider ||= ServiceProvider.find_or_initialize_by(key: "polar").tap do |record|
        record.name          = "Polar"
        record.provider_type = "network"
        record.description   = "Climate and environmental monitoring aggregator exposing sensor readings from connected devices."
        record.settings      = { "device_interfaces" => [ "network" ] }
        record.save!
      end
    end
  end
end
