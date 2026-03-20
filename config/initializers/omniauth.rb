Rails.application.config.middleware.use OmniAuth::Builder do
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

OmniAuth.config.allowed_request_methods = [ :post ]
OmniAuth.config.silence_get_warning = true
