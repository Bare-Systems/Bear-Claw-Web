module Home
  class PackagesController < ApplicationController
    before_action -> { require_role(:operator, :admin) }

    def index; end
  end
end
