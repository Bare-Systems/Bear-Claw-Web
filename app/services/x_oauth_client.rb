require "base64"
require "cgi"
require "digest"
require "json"
require "net/http"
require "openssl"
require "securerandom"
require "uri"

class XOauthClient
  AUTHORIZATION_URL = "https://x.com/i/oauth2/authorize".freeze
  TOKEN_URL = "https://api.x.com/2/oauth2/token".freeze
  ME_URL = "https://api.x.com/2/users/me".freeze
  DEFAULT_SCOPES = %w[tweet.read users.read offline.access].freeze

  class Error < StandardError; end
  class ConfigurationError < Error; end
  class RequestError < Error; end

  def configured?
    client_id.present?
  end

  def build_authorization(verifier:, state:, redirect_uri:)
    raise ConfigurationError, "X_CLIENT_ID is not configured." if client_id.blank?

    challenge = pkce_challenge(verifier)
    params = {
      response_type: "code",
      client_id: client_id,
      redirect_uri: redirect_uri,
      scope: scopes.join(" "),
      state: state,
      code_challenge: challenge,
      code_challenge_method: "S256"
    }

    "#{AUTHORIZATION_URL}?#{URI.encode_www_form(params)}"
  end

  def generate_verifier
    SecureRandom.urlsafe_base64(64).delete("=")
  end

  def exchange_code!(code:, verifier:, redirect_uri:)
    form = {
      code: code,
      grant_type: "authorization_code",
      client_id: client_id,
      redirect_uri: redirect_uri,
      code_verifier: verifier
    }

    post_form!(TOKEN_URL, form)
  end

  def refresh_token!(refresh_token:)
    form = {
      refresh_token: refresh_token,
      grant_type: "refresh_token",
      client_id: client_id
    }

    post_form!(TOKEN_URL, form)
  end

  def me!(access_token:)
    uri = URI.parse(ME_URL)
    uri.query = URI.encode_www_form("user.fields" => "username,name")
    request_json(Net::HTTP::Get.new(uri), access_token:)
  end

  private

  def client_id
    ENV["X_CLIENT_ID"].to_s.strip
  end

  def client_secret
    ENV["X_CLIENT_SECRET"].to_s.strip
  end

  def scopes
    raw = ENV["X_SCOPES"].to_s.strip
    return DEFAULT_SCOPES if raw.blank?

    raw.split(/\s+/)
  end

  def pkce_challenge(verifier)
    digest = OpenSSL::Digest::SHA256.digest(verifier)
    Base64.urlsafe_encode64(digest).delete("=")
  end

  def post_form!(url, form)
    uri = URI.parse(url)
    request = Net::HTTP::Post.new(uri)
    request["Content-Type"] = "application/x-www-form-urlencoded"
    request["Accept"] = "application/json"
    request["Authorization"] = basic_auth_header if client_secret.present?
    request.body = URI.encode_www_form(form)

    request_json(request)
  end

  def request_json(request, access_token: nil)
    uri = request.uri
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = uri.scheme == "https"
    http.open_timeout = 10
    http.read_timeout = 30
    request["Authorization"] = "Bearer #{access_token}" if access_token.present?

    response = http.request(request)
    body = response.body.to_s
    parsed = body.present? ? JSON.parse(body) : {}

    unless response.code.to_i.between?(200, 299)
      detail = parsed["error_description"] || parsed["detail"] || parsed["title"] || body.presence || response.message
      raise RequestError, "X OAuth request failed: #{detail}"
    end

    parsed
  rescue JSON::ParserError => e
    raise RequestError, "X OAuth returned invalid JSON: #{e.message}"
  rescue SocketError, IOError, SystemCallError, Timeout::Error, OpenSSL::SSL::SSLError => e
    raise RequestError, "X OAuth request failed: #{e.message}"
  end

  def basic_auth_header
    encoded = Base64.strict_encode64("#{client_id}:#{client_secret}")
    "Basic #{encoded}"
  end
end
