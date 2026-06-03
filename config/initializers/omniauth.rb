Rails.application.config.middleware.use OmniAuth::Builder do
  if ENV["GOOGLE_CLIENT_ID"].present? && ENV["GOOGLE_CLIENT_SECRET"].present?
    options = {
      scope: "email profile",
      prompt: "select_account"
    }

    # In production, GOOGLE_REDIRECT_URI is set explicitly so the callback URL
    # matches the Google Cloud Console entry for bearclaw.home.
    # In development it's left unset and OmniAuth derives it from the request.
    options[:redirect_uri] = ENV["GOOGLE_REDIRECT_URI"] if ENV["GOOGLE_REDIRECT_URI"].present?

    provider :google_oauth2,
      ENV["GOOGLE_CLIENT_ID"],
      ENV["GOOGLE_CLIENT_SECRET"],
      **options
  end

  oidc_support_enabled = ActiveModel::Type::Boolean.new.cast(ENV["OIDC_SUPPORT_ENABLED"])
  issuer = ENV["OIDC_ISSUER_URL"]

  if oidc_support_enabled &&
      issuer.present? &&
      ENV["OIDC_CLIENT_ID"].present? &&
      ENV["OIDC_CLIENT_SECRET"].present? &&
      ENV["OIDC_REDIRECT_URI"].present?
    # discovery: false — avoids the gem forcing HTTPS for the discovery request,
    # which fails when Keycloak is on plain HTTP (homelab). Endpoints are set explicitly.
    provider :openid_connect,
      name: :oidc,
      scope: %i[openid email profile],
      response_type: :code,
      client_auth_method: :basic,
      discovery: false,
      issuer: issuer,
      client_options: {
        identifier: ENV["OIDC_CLIENT_ID"],
        secret: ENV["OIDC_CLIENT_SECRET"],
        redirect_uri: ENV["OIDC_REDIRECT_URI"],
        authorization_endpoint: "#{issuer}/protocol/openid-connect/auth",
        token_endpoint: "#{issuer}/protocol/openid-connect/token",
        userinfo_endpoint: "#{issuer}/protocol/openid-connect/userinfo",
        jwks_uri: "#{issuer}/protocol/openid-connect/certs",
        end_session_endpoint: ENV["OIDC_LOGOUT_URL"].presence || "#{issuer}/protocol/openid-connect/logout"
      }
  end
end

OmniAuth.config.allowed_request_methods = [ :post ]
OmniAuth.config.silence_get_warning = true
