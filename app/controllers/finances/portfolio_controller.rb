module Finances
  class PortfolioController < BaseController
    def index
      @positions = kodiak_client.positions
      @movers = kodiak_client.movers
    rescue KodiakClient::RequestError => e
      @error = "Could not reach Kodiak (#{e.status}): #{e.message}"
    rescue KodiakClient::Error => e
      @error = e.message
    end
  end
end
