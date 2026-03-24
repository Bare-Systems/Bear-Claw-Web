module Agent
  class MemoryController < ApplicationController
    before_action -> { require_role(:operator, :admin) }

    def index
      result   = bearclaw_client.list_memory
      @entries = result["entries"] || []
    rescue BearClawClient::Error => e
      @entries = []
      flash.now[:alert] = "BearClaw unavailable: #{e.message}"
    end

    def destroy
      bearclaw_client.delete_memory_entry(params[:id])
      redirect_to agent_memory_index_path, notice: "Memory entry deleted."
    rescue BearClawClient::Error => e
      redirect_to agent_memory_index_path, alert: "Failed to delete: #{e.message}"
    end
  end
end
