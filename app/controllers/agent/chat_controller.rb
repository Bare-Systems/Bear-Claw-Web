module Agent
  class ChatController < ApplicationController
    before_action -> { require_role(:operator, :admin) }

    def index; end

    def create
      content = params[:message].to_s.strip
      return head(:unprocessable_entity) if content.blank?

      @user_message = { id: SecureRandom.uuid, role: "user", content: content }

      begin
        result        = bearclaw_client.chat(content)
        reply         = result.dig("message", "content").to_s
        reply         = "(no response)" if reply.blank?
        @agent_message = {
          id:      result.dig("message", "id") || SecureRandom.uuid,
          role:    "assistant",
          content: reply
        }
      rescue BearClawClient::TimeoutError
        @agent_message = { id: SecureRandom.uuid, role: "error", content: "BearClaw timed out. The agent may be busy — try again." }
      rescue BearClawClient::ConfigurationError => e
        @agent_message = { id: SecureRandom.uuid, role: "error", content: "Configuration error: #{e.message}" }
      rescue BearClawClient::Error => e
        @agent_message = { id: SecureRandom.uuid, role: "error", content: e.message }
      end

      respond_to do |format|
        format.turbo_stream
        format.html { redirect_to agent_chat_index_path }
      end
    end

  end
end
