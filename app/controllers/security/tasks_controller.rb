module Security
  class TasksController < BaseController
    def index
      @filters = params.permit(:session_id, :status, :campaign, :tag).to_h
      @tasks = ursa_client.get_json("/api/v1/tasks", params: @filters)["tasks"]
    end

    def show
      @task = ursa_client.get_json("/api/v1/tasks/#{params[:id]}")["task"]
    end
  end
end
