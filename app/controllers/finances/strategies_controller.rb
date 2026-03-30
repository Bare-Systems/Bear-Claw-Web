module Finances
  class StrategiesController < BaseController
    def index
      @strategies = kodiak_client.strategies
    rescue KodiakClient::RequestError => e
      @error = "Could not reach Kodiak (#{e.status}): #{e.message}"
    rescue KodiakClient::Error => e
      @error = e.message
    end

    def pause
      kodiak_client.pause_strategy(params[:id])
      @strategy = kodiak_client.strategy(params[:id])
      respond_to do |format|
        format.turbo_stream
        format.html { redirect_to finances_strategies_path }
      end
    rescue KodiakClient::Error => e
      flash[:alert] = "Failed to pause strategy: #{e.message}"
      redirect_to finances_strategies_path
    end

    def resume
      kodiak_client.resume_strategy(params[:id])
      @strategy = kodiak_client.strategy(params[:id])
      respond_to do |format|
        format.turbo_stream
        format.html { redirect_to finances_strategies_path }
      end
    rescue KodiakClient::Error => e
      flash[:alert] = "Failed to resume strategy: #{e.message}"
      redirect_to finances_strategies_path
    end
  end
end
