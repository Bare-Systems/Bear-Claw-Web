class ApplicationController < ActionController::Base
  allow_browser versions: :modern

  before_action :require_login

  helper_method :current_user, :current_home, :home_member?

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

  def current_home
    @current_home ||= Household.first
  end

  def home_member?
    return false unless current_user && current_home
    current_home.member?(current_user) || current_user.admin?
  end

  def require_home_membership
    unless home_member?
      redirect_to login_path, alert: "You are not a member of this home."
    end
  end

  def bearclaw_client
    BearClawClient.new(
      base_url: ENV.fetch("BEARCLAW_URL", "http://127.0.0.1:8080"),
      token: ENV["BEARCLAW_TOKEN"],
      identity_token: ensure_tardigrade_identity_token
    )
  end

  def ensure_tardigrade_identity_token
    return nil unless current_user
    token = session[:tardigrade_identity_token].to_s
    return token if token.present?

    issued = TardigradeIdentityToken.issue_for(current_user)
    session[:tardigrade_identity_token] = issued
    issued
  end
end
