module Finances
  class DashboardController < BaseController
    def index
      @engine_status = kodiak_client.engine_status
      @portfolio = kodiak_client.portfolio_summary
      @positions = kodiak_client.positions
      @signal_overview = kodiak_client.market_signal_overview
      @signal_alerts = kodiak_client.market_signal_alerts(limit: 10)
      @signal_sources = kodiak_client.market_signal_sources
    rescue KodiakClient::ConfigurationError => e
      @error = "Kodiak is not configured: #{e.message}"
    rescue KodiakClient::RequestError => e
      @error = "Could not reach Kodiak (#{e.status}): #{e.message}"
    rescue KodiakClient::Error => e
      @error = e.message
    end
  end
end
