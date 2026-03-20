module Home
  class CamerasController < ApplicationController
    before_action -> { require_role(:operator, :admin) }

    def index; end
    def show; end
  end
end
