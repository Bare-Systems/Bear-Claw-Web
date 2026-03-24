module Agent
  class CronController < ApplicationController
    before_action -> { require_role(:operator, :admin) }

    def index
      result = bearclaw_client.list_cron_jobs
      @jobs  = result["jobs"] || []
    rescue BearClawClient::Error => e
      @jobs = []
      flash.now[:alert] = "BearClaw unavailable: #{e.message}"
    end

    def create
      bearclaw_client.create_cron_job(
        name:     params[:name].to_s.strip,
        schedule: params[:schedule].to_s.strip,
        command:  params[:command].to_s.strip,
        args:     JSON.parse(params[:args].presence || "{}"),
        enabled:  params[:enabled] != "0"
      )
      redirect_to agent_cron_index_path, notice: "Cron job created."
    rescue JSON::ParserError
      redirect_to agent_cron_index_path, alert: "Invalid JSON in args field."
    rescue BearClawClient::Error => e
      redirect_to agent_cron_index_path, alert: "Failed to create: #{e.message}"
    end

    def update
      attrs = {}
      attrs[:name]     = params[:name]     if params[:name].present?
      attrs[:schedule] = params[:schedule]  if params[:schedule].present?
      attrs[:enabled]  = params[:enabled] == "1" if params.key?(:enabled)
      bearclaw_client.update_cron_job(params[:id], **attrs)
      redirect_to agent_cron_index_path, notice: "Cron job updated."
    rescue BearClawClient::Error => e
      redirect_to agent_cron_index_path, alert: "Failed to update: #{e.message}"
    end

    def destroy
      bearclaw_client.delete_cron_job(params[:id])
      redirect_to agent_cron_index_path, notice: "Cron job deleted."
    rescue BearClawClient::Error => e
      redirect_to agent_cron_index_path, alert: "Failed to delete: #{e.message}"
    end
  end
end
