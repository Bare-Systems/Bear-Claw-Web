module Settings
  class BaseController < ApplicationController
    before_action :require_operator!

    private

    def require_operator!
      unless current_user&.can_access?(:home)
        redirect_to root_path, alert: "You do not have access to Settings."
      end
    end
  end
end
