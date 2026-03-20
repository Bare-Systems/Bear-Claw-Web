class SessionsController < ApplicationController
  skip_before_action :require_login, only: [ :new, :create, :failure ]

  def new
    redirect_to root_path if current_user
  end

  def create
    auth = request.env["omniauth.auth"]

    if auth&.dig("info")
      user = User.from_google(auth)
      session[:user_id] = user.id
      redirect_to root_path, notice: "Signed in as #{user.name}."
    else
      redirect_to login_path, alert: "Authentication failed."
    end
  rescue => e
    Rails.logger.error("Google OAuth error: #{e.message}")
    redirect_to login_path, alert: "Authentication failed. Please try again."
  end

  def failure
    redirect_to login_path, alert: "Authentication failed: #{params[:message]}"
  end

  def destroy
    reset_session
    redirect_to login_path, notice: "Signed out."
  end
end
