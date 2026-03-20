module Home
  class DashboardController < ApplicationController
    before_action -> { require_role(:operator, :admin) }

    def index; end
  end
end
