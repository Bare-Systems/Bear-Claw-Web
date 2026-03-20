module Security
  class EventsController < BaseController
    def index
      @filters = params.permit(:level, :session_id, :campaign, :tag).to_h
      @events = ursa_client.get_json("/api/v1/events", params: @filters)["events"]
    end
  end
end
