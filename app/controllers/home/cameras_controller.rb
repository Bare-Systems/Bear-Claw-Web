module Home
  class CamerasController < ApplicationController
    include KoalaCameraSlots

    before_action -> { require_role(:operator, :admin) }

    def index
      @camera_slots = build_camera_slots
    rescue KoalaClient::Error => e
      @camera_slots = []
      @koala_error = e.message
    end

    def snapshot
      download = koala_client.snapshot(params[:id])
      response.headers["Cache-Control"] = "no-cache, no-store, must-revalidate"
      send_data download.body, type: download.content_type, disposition: "inline"
    rescue KoalaClient::RequestError => e
      head snapshot_error_status(e)
    end

    def show; end

    private

    def snapshot_error_status(error)
      return :not_found if error.status == 404
      return :unauthorized if error.status == 401

      :bad_gateway
    end
  end
end
