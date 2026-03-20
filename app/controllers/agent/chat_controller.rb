module Agent
  class ChatController < ApplicationController
    before_action -> { require_role(:operator, :admin) }

    def index; end
    def create; end
  end
end
