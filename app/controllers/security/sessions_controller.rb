module Security
  class SessionsController < BaseController
    def index
      @filters = params.permit(:status, :campaign, :tag).to_h
      @sessions = ursa_client.get_json("/api/v1/sessions", params: @filters)["sessions"]
    end

    def show
      payload = ursa_client.get_json("/api/v1/sessions/#{params[:id]}")
      @session = payload["session"]
      @tasks = payload["tasks"]
      @files = payload["files"]
      @events = payload["events"]
    end

    def context
      ursa_client.patch_json("/api/v1/sessions/#{params[:id]}/context", payload: {
        campaign: params[:campaign],
        tags: params[:tags]
      })
      redirect_to security_session_path(params[:id]), notice: "Session context updated."
    end

    def queue_task
      payload = {
        task_type: params[:task_type],
        command: params[:command]
      }
      ursa_client.post_json("/api/v1/sessions/#{params[:id]}/tasks", payload: payload)
      redirect_to security_session_path(params[:id]), notice: "Task queued."
    end

    def kill
      ursa_client.post_json("/api/v1/sessions/#{params[:id]}/kill", payload: {})
      redirect_to security_session_path(params[:id]), notice: "Kill task queued and session marked dead."
    end
  end
end
