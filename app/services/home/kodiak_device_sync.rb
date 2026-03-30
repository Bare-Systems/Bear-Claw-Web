module Home
  class KodiakDeviceSync
    def initialize(client:, base_url:, user:)
      @client   = client
      @base_url = base_url.to_s.strip
      @user     = user
    end

    def sync!
      engine    = @client.engine_status
      portfolio = @client.portfolio_summary

      connection.update!(
        name:                "Kodiak",
        adapter:             "kodiak",
        base_url:            @base_url,
        credential_strategy: "environment",
        status:              "online",
        last_error:          nil
      )

      upsert_engine_device!(engine)
      upsert_portfolio_device!(portfolio)
    rescue KodiakClient::Error => e
      connection.update!(
        name:                "Kodiak",
        adapter:             "kodiak",
        base_url:            @base_url,
        credential_strategy: "environment",
        status:              "error",
        last_error:          e.message
      )
      raise
    end

    private

    def upsert_engine_device!(engine)
      running = engine["running"].present? && engine["running"] != false

      device = Device.find_or_initialize_by(key: "kodiak-engine")
      device.user              = @user
      device.service_connection = connection
      device.name              = "Kodiak Engine"
      device.category          = "network_service"
      device.source_kind       = "network"
      device.source_identifier = "kodiak:engine"
      device.status            = running ? "available" : "degraded"
      device.metadata          = {
        "mode"    => engine["mode"],
        "dry_run" => engine["dry_run"]
      }.compact
      device.save!

      capability = device.device_capabilities.find_or_initialize_by(key: "engine_status")
      capability.name            = "Engine Status"
      capability.capability_type = "status"
      capability.configuration   = { "service" => "kodiak" }
      capability.state           = {
        "status"          => running ? "running" : "stopped",
        "mode"            => engine["mode"],
        "dry_run"         => engine["dry_run"],
        "strategy_count"  => engine["strategy_count"],
        "last_seen_at"    => Time.current.iso8601
      }.compact
      capability.save!

      device
    end

    def upsert_portfolio_device!(portfolio)
      device = Device.find_or_initialize_by(key: "kodiak-portfolio")
      device.user              = @user
      device.service_connection = connection
      device.name              = "Kodiak Portfolio"
      device.category          = "network_service"
      device.source_kind       = "network"
      device.source_identifier = "kodiak:portfolio"
      device.status            = "available"
      device.metadata          = {}
      device.save!

      PORTFOLIO_METRICS.each do |metric|
        raw = portfolio[metric[:field]]
        next if raw.nil?

        capability = device.device_capabilities.find_or_initialize_by(key: metric[:key])
        capability.name            = metric[:name]
        capability.capability_type = "finance"
        capability.configuration   = { "metric" => metric[:field], "service" => "kodiak" }
        capability.state           = {
          "value"        => raw.to_f.round(2),
          "unit"         => "USD",
          "quality"      => "good",
          "last_seen_at" => Time.current.iso8601
        }
        capability.save!
      end

      device
    end

    PORTFOLIO_METRICS = [
      { key: "portfolio_equity",       name: "Total Equity",    field: "equity"       },
      { key: "portfolio_cash",         name: "Cash",            field: "cash"         },
      { key: "portfolio_buying_power", name: "Buying Power",    field: "buying_power" },
      { key: "portfolio_day_pnl",      name: "Day P&L",         field: "day_pnl"      },
      { key: "portfolio_unrealized",   name: "Unrealized P&L",  field: "unrealized_pl" }
    ].freeze

    def connection
      @connection ||= ServiceConnection.find_or_initialize_by(key: "kodiak").tap do |record|
        record.service_provider = provider
      end
    end

    def provider
      @provider ||= ServiceProvider.find_or_initialize_by(key: "kodiak").tap do |record|
        record.name          = "Kodiak"
        record.provider_type = "network"
        record.description   = "Algorithmic trading engine and portfolio management service."
        record.settings      = { "device_interfaces" => [ "network" ] }
        record.save!
      end
    end
  end
end
