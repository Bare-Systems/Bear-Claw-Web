module Admin
  class DashboardController < ApplicationController
    before_action -> { require_role(:admin) }

    def index; end
  end
end
