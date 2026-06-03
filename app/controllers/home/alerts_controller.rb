module Home
  class AlertsController < ApplicationController
    include KoalaCameraSlots

    before_action -> { require_role(:operator, :admin) }

    def snapshot
      download = koala_client.alert_snapshot(params[:id])
      response.headers["Cache-Control"] = "private, max-age=31536000, immutable"
      send_data download.body, type: download.content_type, disposition: "inline"
    rescue KoalaClient::RequestError => e
      head snapshot_error_status(e)
    end

    private

    def snapshot_error_status(error)
      return :not_found if error.status == 404
      return :unauthorized if error.status == 401

      :bad_gateway
    end
  end
end
