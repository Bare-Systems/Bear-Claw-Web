module Agent
  class RunsController < ApplicationController
    before_action -> { require_role(:operator, :admin) }

    def index
      payload = bearclaw_client.list_runs
      @runs = Array(payload["runs"])
      @error_message = nil
    rescue BearClawClient::Error => e
      @runs = []
      @error_message = e.message
    end

    def show
      payload = bearclaw_client.get_run(params[:id])
      @run = payload["run"] || {}
      @events = Array(payload["events"])
      @error_message = nil
    rescue BearClawClient::RequestError => e
      if e.status == 404
        redirect_to agent_runs_path, alert: "Run not found." and return
      end

      @run = { "id" => params[:id], "status" => "error", "event_count" => 0 }
      @events = []
      @error_message = e.message
      render :show
    rescue BearClawClient::Error => e
      @run = { "id" => params[:id], "status" => "error", "event_count" => 0 }
      @events = []
      @error_message = e.message
      render :show
    end

    def stream
      response.headers["Content-Type"] = "text/event-stream"
      response.headers["Cache-Control"] = "no-cache"
      response.headers["X-Accel-Buffering"] = "no"
      self.response_body = bearclaw_client.stream_run(params[:id])
    rescue BearClawClient::RequestError => e
      render plain: e.message, status: e.status
    rescue BearClawClient::Error => e
      render plain: e.message, status: :bad_gateway
    end
  end
end
