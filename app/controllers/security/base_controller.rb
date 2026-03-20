module Security
  class BaseController < ApplicationController
    before_action -> { require_role(:admin) }
    rescue_from UrsaClient::ConfigurationError, with: :handle_ursa_error
    rescue_from UrsaClient::RequestError, with: :handle_ursa_error

    private

    def ursa_client
      @ursa_client ||= UrsaClient.new(
        base_url: ENV["URSA_URL"],
        token: ENV["URSA_TOKEN"],
        actor: current_user.email.presence || current_user.name.presence || "bearclaw-admin"
      )
    end

    def render_ursa_download(download)
      download.headers.each do |key, value|
        next if value.blank?
        next if %w[content-length transfer-encoding connection].include?(key.downcase)

        response.set_header(key, value)
      end

      render body: download.body, content_type: download.content_type
    end

    def redirect_back_to(default_path, **options)
      redirect_back fallback_location: default_path, **options
    end

    def handle_ursa_error(error)
      if request.get?
        redirect_to security_root_path, alert: error.message
      else
        redirect_back_to security_root_path, alert: error.message
      end
    end
  end
end
