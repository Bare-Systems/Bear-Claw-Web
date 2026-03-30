module Home
  class UrsaDeviceSync
    def initialize(client:, base_url:, user:)
      @client   = client
      @base_url = base_url.to_s.strip
      @user     = user
    end

    def sync!
      sessions  = Array(@client.get_json("/api/v1/sessions")["sessions"])
      campaigns = Array(@client.get_json("/api/v1/campaigns")["campaigns"])

      connection.update!(
        name:                "Ursa",
        adapter:             "ursa",
        base_url:            @base_url,
        credential_strategy: "environment",
        status:              "online",
        last_error:          nil
      )

      upsert_sessions_capability!(sessions)
      upsert_campaigns_capability!(campaigns)
    rescue UrsaClient::Error => e
      connection.update!(
        name:                "Ursa",
        adapter:             "ursa",
        base_url:            @base_url,
        credential_strategy: "environment",
        status:              "error",
        last_error:          e.message
      )
      raise
    end

    private

    def upsert_sessions_capability!(sessions)
      active   = sessions.count { |s| s.is_a?(Hash) && s["status"].to_s == "active" }
      inactive = sessions.size - active

      cap = overview_device.device_capabilities.find_or_initialize_by(key: "ursa_sessions")
      cap.name            = "Active Sessions"
      cap.capability_type = "status"
      cap.configuration   = { "service" => "ursa", "metric" => "sessions" }
      cap.state           = {
        "value"       => active,
        "unit"        => "sessions",
        "status"      => active > 0 ? "active" : "available",
        "breakdown"   => { "Active" => active, "Inactive" => inactive, "Total" => sessions.size },
        "last_seen_at" => Time.current.iso8601
      }
      cap.save!
    end

    def upsert_campaigns_capability!(campaigns)
      open_count   = campaigns.count { |c| c.is_a?(Hash) && %w[active open].include?(c["status"].to_s) }
      closed_count = campaigns.size - open_count

      cap = overview_device.device_capabilities.find_or_initialize_by(key: "ursa_campaigns")
      cap.name            = "Campaigns"
      cap.capability_type = "status"
      cap.configuration   = { "service" => "ursa", "metric" => "campaigns" }
      cap.state           = {
        "value"       => open_count,
        "unit"        => "campaigns",
        "status"      => open_count > 0 ? "active" : "available",
        "breakdown"   => { "Open" => open_count, "Closed" => closed_count, "Total" => campaigns.size },
        "last_seen_at" => Time.current.iso8601
      }
      cap.save!
    end

    def overview_device
      @overview_device ||= begin
        device = Device.find_or_initialize_by(key: "ursa-overview")
        device.user              = @user
        device.service_connection = connection
        device.name              = "Ursa C2"
        device.category          = "network_service"
        device.source_kind       = "network"
        device.source_identifier = "ursa:overview"
        device.status            = "available"
        device.metadata          = {}
        device.save!
        device
      end
    end

    def connection
      @connection ||= ServiceConnection.find_or_initialize_by(key: "ursa").tap do |record|
        record.service_provider = provider
      end
    end

    def provider
      @provider ||= ServiceProvider.find_or_initialize_by(key: "ursa").tap do |record|
        record.name          = "Ursa"
        record.provider_type = "network"
        record.description   = "Red-team C2 framework providing session and campaign telemetry."
        record.settings      = { "device_interfaces" => [ "network" ] }
        record.save!
      end
    end
  end
end
