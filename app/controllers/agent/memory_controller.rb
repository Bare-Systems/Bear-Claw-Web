module Agent
  class MemoryController < ApplicationController
    before_action -> { require_role(:operator, :admin) }

    def index; end
    def destroy; end
  end
end
