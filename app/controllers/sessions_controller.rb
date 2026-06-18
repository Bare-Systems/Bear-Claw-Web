class SessionsController < ApplicationController
  skip_before_action :require_login, only: [ :new, :create, :failure, :dev_login, :accept_invite, :portal ]
  helper_method :google_login_enabled?, :support_oidc_enabled?, :primary_auth_provider

  def new
    return redirect_to(root_path) if current_user
    # No local login page when fronted by the Portal — send users to the Portal
    # device-selection dashboard to authenticate and pick a device.
    if (url = portal_redirect_url)
      redirect_to url, allow_other_host: true
    end
  end

  def create
    auth  = request.env["omniauth.auth"]
    token = session.delete(:invite_token)

    unless auth&.dig("info")
      redirect_to login_path, alert: "Authentication failed." and return
    end

    invite = token.present? ? Invite.find_by(token: token) : nil
    user   = User.from_omniauth(auth, invite: invite)

    establish_session!(user)
    redirect_to root_path, notice: "Signed in as #{user.name}."

  rescue User::InviteRequiredError
    redirect_to login_path, alert: "Access to BearClaw is by invitation only."
  rescue User::InviteEmailMismatchError
    redirect_to login_path, alert: "This invite is not valid for your Google account."
  rescue User::SupportAccessDeniedError
    redirect_to login_path, alert: "This support login is not enabled for your account."
  rescue => e
    Rails.logger.error("OmniAuth error (#{params[:provider]}): #{e.class}: #{e.message}")
    redirect_to login_path, alert: "Authentication failed. Please try again."
  end

  def accept_invite
    invite = Invite.find_by(token: params[:token])

    unless invite&.usable?
      redirect_to login_path, alert: "This invite link is invalid or has expired." and return
    end

    session[:invite_token] = invite.token
    redirect_to "/auth/#{primary_auth_provider}"
  end

  def failure
    redirect_to login_path, alert: "Authentication failed: #{params[:message]}"
  end

  def destroy
    reset_session
    # The Portal is the SSO front door, so signing out returns the user to the
    # Portal's device-selection dashboard rather than this device's local login.
    if (url = portal_redirect_url)
      redirect_to url, allow_other_host: true, notice: "Signed out."
    else
      redirect_to login_path, notice: "Signed out."
    end
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

    establish_session!(user)
    redirect_to root_path, notice: "Signed in as #{user.name} (dev)."
  end

  # Single sign-on handoff from the BareSystems Portal. The Portal authenticated
  # the user and signed a short-lived identity assertion; we verify it and
  # establish a local session, applying the per-device role it carries.
  def portal
    raise ActionController::RoutingError, "Not Found" unless PortalIdentityToken.enabled?

    payload = PortalIdentityToken.verify(params[:token].to_s)
    email   = payload["email"].to_s.downcase
    raise PortalIdentityToken::InvalidToken, "missing email" if email.blank?

    # Match an existing account by email first so we never clobber a user's
    # Google identity (google_uid). Only genuinely new users fall through to the
    # invite-gated creation path.
    user = User.find_by(email: email) || User.from_omniauth(portal_auth_hash(payload), invite: nil)
    apply_portal_role!(user, payload["role"])

    establish_session!(user)
    redirect_to root_path, notice: "Signed in via Portal as #{user.name}."
  rescue PortalIdentityToken::InvalidToken
    redirect_to login_path, alert: "Portal sign-in link is invalid or has expired."
  rescue User::InviteRequiredError
    redirect_to login_path, alert: "Access to BearClaw is by invitation only."
  rescue User::InviteEmailMismatchError
    redirect_to login_path, alert: "This invite is not valid for your account."
  end

  private

  def portal_auth_hash(payload)
    OmniAuth::AuthHash.new(
      provider: "portal",
      uid:      payload["sub"].presence || payload["email"],
      info: {
        email: payload["email"],
        name:  payload["name"]
      }
    )
  end

  # Map the Portal's per-device role onto this instance: owner gets edit access
  # (operator), an invited viewer gets read-only. Never demote an existing admin.
  def apply_portal_role!(user, claimed_role)
    target =
      if claimed_role.to_s == "owner"
        user.admin? ? :admin : :operator
      else
        :viewer
      end
    user.update!(role: target) unless user.role.to_s == target.to_s
  end

  def google_login_enabled?
    ENV["GOOGLE_CLIENT_ID"].present? && ENV["GOOGLE_CLIENT_SECRET"].present?
  end

  def support_oidc_enabled?
    ActiveModel::Type::Boolean.new.cast(ENV["OIDC_SUPPORT_ENABLED"]) &&
      ENV["OIDC_ISSUER_URL"].present? &&
      ENV["OIDC_CLIENT_ID"].present? &&
      ENV["OIDC_CLIENT_SECRET"].present? &&
      ENV["OIDC_REDIRECT_URI"].present?
  end

  def primary_auth_provider
    google_login_enabled? ? "google_oauth2" : "oidc"
  end

  def establish_session!(user)
    session[:user_id] = user.id
    session[:tardigrade_identity_token] = TardigradeIdentityToken.issue_for(user)
  end
end
