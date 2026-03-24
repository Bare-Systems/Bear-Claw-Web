module Home
  class KoalaDeviceSync
    DVR_KEY = "koala-dvr".freeze

    def initialize(client:, base_url:, user: nil)
      @client = client
      @base_url = base_url.to_s.strip
      @user = user
    end

    def sync!
      payload = @client.list_cameras
      cameras = payload.dig("data", "cameras") || []

      connection.update!(
        name: "Koala",
        adapter: "koala",
        base_url: @base_url,
        credential_strategy: "environment",
        status: "online",
        last_error: nil
      )

      upsert_inventory!(cameras)
    rescue KoalaClient::Error => e
      connection.update!(
        name: "Koala",
        adapter: "koala",
        base_url: @base_url,
        credential_strategy: "environment",
        status: "error",
        last_error: e.message
      )
      upsert_inventory!([])
      raise
    end

    private

    def upsert_inventory!(cameras)
      camera_index = cameras.index_by { |camera| camera["id"] }

      dvr = Device.find_or_initialize_by(key: DVR_KEY)
      dvr.user ||= @user
      dvr.service_connection = connection
      dvr.name = "Blink DVR"
      dvr.category = "dvr"
      dvr.source_kind = "physical"
      dvr.source_identifier = "dvr"
      dvr.status = aggregate_status(camera_index.values)
      dvr.metadata = {
        "camera_count" => KoalaClient::DEFAULT_CAMERA_IDS.length,
        "base_url" => @base_url
      }
      dvr.save!

      KoalaClient::DEFAULT_CAMERA_IDS.each do |camera_id|
        camera = camera_index[camera_id] || {}
        capability = camera["capability"] || {}
        status = camera["status"].presence || "unknown"
        name = camera["name"].presence || camera_id.upcase.tr("_", " ")

        device = Device.find_or_initialize_by(key: "koala-camera-#{camera_id}")
        device.user ||= @user
        device.service_connection = connection
        device.parent_device = dvr
        device.name = name
        device.category = "camera"
        device.source_kind = "physical"
        device.source_identifier = camera_id
        device.status = normalize_device_status(status)
        device.metadata = {
          "zone_id" => camera["zone_id"].presence || "unassigned",
          "selected_source" => capability["selected_source"].presence || "snapshot",
          "last_error" => capability["last_error"].presence,
          "last_probed_at" => capability["last_probed_at"].presence
        }.compact
        device.save!

        feed = device.device_capabilities.find_or_initialize_by(key: "primary_feed")
        feed.name = "#{name} Feed"
        feed.capability_type = "camera_feed"
        feed.configuration = {
          "camera_id" => camera_id,
          "zone_id" => camera["zone_id"].presence || "unassigned"
        }
        feed.state = {
          "camera_id" => camera_id,
          "status" => status,
          "selected_source" => capability["selected_source"].presence || "snapshot",
          "last_error" => capability["last_error"].presence,
          "last_probed_at" => capability["last_probed_at"].presence
        }.compact
        feed.save!
      end
    end

    def aggregate_status(cameras)
      return "unknown" if cameras.blank?

      statuses = cameras.map { |camera| normalize_device_status(camera["status"]) }
      return "available" if statuses.all?("available")
      return "unavailable" if statuses.all?("unavailable")

      "degraded"
    end

    def normalize_device_status(status)
      case status.to_s
      when "available" then "available"
      when "degraded" then "degraded"
      when "unavailable" then "unavailable"
      else "unknown"
      end
    end

    def connection
      @connection ||= ServiceConnection.find_or_initialize_by(key: "koala").tap do |record|
        record.service_provider = provider
      end
    end

    def provider
      @provider ||= ServiceProvider.find_or_initialize_by(key: "koala").tap do |record|
        record.name = "Koala"
        record.provider_type = "hybrid"
        record.description = "Home orchestration provider exposing camera devices and house-state APIs."
        record.settings = {
          "device_interfaces" => [ "physical", "network" ]
        }
        record.save!
      end
    end
  end
end
