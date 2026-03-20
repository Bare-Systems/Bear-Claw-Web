module Security
  class DashboardController < BaseController
    def index
      @overview = ursa_client.get_json("/api/v1/overview")
    end
  end
end
