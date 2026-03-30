module Finances
  module Engine
    class StatusController < BaseController
      def index
        @engine_status = kodiak_client.engine_status
      rescue KodiakClient::RequestError => e
        @error = "Could not reach Kodiak (#{e.status}): #{e.message}"
      rescue KodiakClient::Error => e
        @error = e.message
      end

      def start
        kodiak_client.start_engine(dry_run: params[:dry_run] == "1", interval: 60)
        redirect_to finances_engine_root_path, notice: "Engine started."
      rescue KodiakClient::Error => e
        redirect_to finances_engine_root_path, alert: "Failed to start engine: #{e.message}"
      end

      def stop
        kodiak_client.stop_engine
        redirect_to finances_engine_root_path, notice: "Engine stopped."
      rescue KodiakClient::Error => e
        redirect_to finances_engine_root_path, alert: "Failed to stop engine: #{e.message}"
      end
    end
  end
end
