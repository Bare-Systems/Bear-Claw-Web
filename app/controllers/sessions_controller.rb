class SessionsController < ApplicationController
  skip_before_action :require_login, only: [ :new, :create, :failure, :dev_login, :accept_invite ]

  def new
    redirect_to root_path if current_user
  end

  def create
    auth  = request.env["omniauth.auth"]
    token = session.delete(:invite_token)

    unless auth&.dig("info")
      redirect_to login_path, alert: "Authentication failed." and return
    end

    invite = token.present? ? Invite.find_by(token: token) : nil
    user   = User.from_google(auth, invite: invite)

    session[:user_id] = user.id
    redirect_to root_path, notice: "Signed in as #{user.name}."

  rescue User::InviteRequiredError
    redirect_to login_path, alert: "Access to BearClaw is by invitation only."
  rescue User::InviteEmailMismatchError
    redirect_to login_path, alert: "This invite is not valid for your Google account."
  rescue => e
    Rails.logger.error("Google OAuth error: #{e.class}: #{e.message}")
    redirect_to login_path, alert: "Authentication failed. Please try again."
  end

  def accept_invite
    invite = Invite.find_by(token: params[:token])

    unless invite&.usable?
      redirect_to login_path, alert: "This invite link is invalid or has expired." and return
    end

    session[:invite_token] = invite.token
    redirect_to "/auth/google_oauth2"
  end

  def failure
    redirect_to login_path, alert: "Authentication failed: #{params[:message]}"
  end

  def destroy
    reset_session
    redirect_to login_path, notice: "Signed out."
  end

  def dev_login
    raise ActionController::RoutingError, "Not Found" unless Rails.env.development? || Rails.env.test?

    user = if Rails.env.test? && params[:email].present?
      User.find_by!(email: params[:email])
    else
      User.find_or_create_by!(email: "dev@bearclaw.local") do |u|
        u.name       = "Dev Admin"
        u.google_uid = "dev-local-admin"
        u.role       = :admin
        u.avatar_url = nil
      end
    end

    session[:user_id] = user.id
    redirect_to root_path, notice: "Signed in as #{user.name} (dev)."
  end
end
