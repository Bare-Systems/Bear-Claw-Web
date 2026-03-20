module Agent
  class CronController < ApplicationController
    before_action -> { require_role(:operator, :admin) }

    def index; end
    def create; end
    def update; end
    def destroy; end
  end
end
