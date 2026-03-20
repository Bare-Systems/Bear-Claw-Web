class ApplicationController < ActionController::Base
  allow_browser versions: :modern

  before_action :require_login

  helper_method :current_user

  private

  def current_user
    @current_user ||= User.find_by(id: session[:user_id])
  end

  def require_login
    redirect_to login_path unless current_user
  end

  def require_role(*roles)
    unless roles.any? { |r| current_user&.role == r.to_s }
      redirect_to root_path, alert: "Access denied."
    end
  end
end
