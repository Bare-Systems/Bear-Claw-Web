module Settings
  class XIntegrationsController < BaseController
    def connect
      unless x_oauth_client.configured?
        redirect_to settings_integrations_path, alert: "X OAuth is not configured." and return
      end

      verifier = x_oauth_client.generate_verifier
      state = SecureRandom.hex(24)
      session[:x_oauth_verifier] = verifier
      session[:x_oauth_state] = state

      redirect_to x_oauth_client.build_authorization(
        verifier: verifier,
        state: state,
        redirect_uri: x_redirect_uri
      ), allow_other_host: true
    end

    def callback
      if params[:error].present?
        redirect_to settings_integrations_path, alert: "X authorization failed: #{params[:error]}" and return
      end

      verifier = session.delete(:x_oauth_verifier).to_s
      expected_state = session.delete(:x_oauth_state).to_s

      if verifier.blank? || expected_state.blank? || params[:state].to_s != expected_state
        redirect_to settings_integrations_path, alert: "X authorization could not be verified." and return
      end

      tokens = x_oauth_client.exchange_code!(
        code: params[:code].to_s,
        verifier: verifier,
        redirect_uri: x_redirect_uri
      )
      profile = x_oauth_client.me!(access_token: tokens.fetch("access_token"))

      integration = Integration.find_or_initialize_by(provider_key: "x")
      integration.name = "X"
      integration.status = "connected"
      integration.credentials = {
        "x_user_id" => profile.dig("data", "id"),
        "username" => profile.dig("data", "username"),
        "name" => profile.dig("data", "name"),
        "scope" => tokens["scope"],
        "token_type" => tokens["token_type"]
      }
      integration.settings = {
        "connected_via" => "oauth2_pkce",
        "redirect_uri" => x_redirect_uri
      }
      integration.last_error = nil
      integration.last_verified_at = Time.current
      integration.save!

      kodiak_client.connect_x_oauth(
        x_user_id: profile.dig("data", "id"),
        username: profile.dig("data", "username"),
        access_token: tokens.fetch("access_token"),
        refresh_token: tokens["refresh_token"],
        token_type: tokens["token_type"],
        scope: tokens["scope"],
        expires_in: tokens["expires_in"]
      )

      redirect_to settings_integrations_path, notice: "X connected successfully."
    rescue ::XOauthClient::Error, KodiakClient::Error, ActiveRecord::ActiveRecordError => e
      Integration.find_or_initialize_by(provider_key: "x").tap do |integration|
        integration.name = "X"
        integration.status = "error"
        integration.last_error = e.message
        integration.save(validate: false)
      end
      redirect_to settings_integrations_path, alert: e.message
    end

    private

    def x_oauth_client
      @x_oauth_client ||= ::XOauthClient.new
    end

    def kodiak_client
      @kodiak_client ||= KodiakClient.new(
        base_url: ENV.fetch("KODIAK_URL", "http://192.168.86.53:6702"),
        token: ENV.fetch("KODIAK_TOKEN", ""),
        actor: current_user&.email,
        role: current_user&.role&.to_s
      )
    end

    def x_redirect_uri
      ENV["X_REDIRECT_URI"].presence || settings_x_callback_url
    end
  end
end
