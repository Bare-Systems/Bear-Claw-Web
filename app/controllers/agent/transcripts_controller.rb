module Agent
  class TranscriptsController < ApplicationController
    before_action -> { require_role(:operator, :admin) }

    def index
      payload = bearclaw_client.list_transcripts
      @transcripts = Array(payload["transcripts"])
      @error_message = nil
    rescue BearClawClient::Error => e
      @transcripts = []
      @error_message = e.message
    end

    def show
      payload = bearclaw_client.get_transcript(params[:id])
      @transcript = payload["transcript"] || {}
      @error_message = nil
    rescue BearClawClient::RequestError => e
      if e.status == 404
        redirect_to agent_transcripts_path, alert: "Transcript not found." and return
      end

      @transcript = { "id" => params[:id] }
      @error_message = e.message
      render :show
    rescue BearClawClient::Error => e
      @transcript = { "id" => params[:id] }
      @error_message = e.message
      render :show
    end
  end
end
