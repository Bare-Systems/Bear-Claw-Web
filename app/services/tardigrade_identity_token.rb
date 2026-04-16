require "jwt"

class TardigradeIdentityToken
  class ConfigurationError < StandardError; end

  DEFAULT_ISSUER = "bearclaw-web"
  DEFAULT_AUDIENCE = "bearclaw-api"
  DEFAULT_DEVICE_ID = "bearclaw-web"
  DEFAULT_TTL_SECONDS = 3600

  def self.issue_for(user, now: Time.current)
    payload = {
      "sub" => user.id.to_s,
      "iss" => issuer,
      "aud" => audience,
      "scope" => scopes_for(user),
      "device_id" => device_id,
      "exp" => now.to_i + ttl_seconds
    }

    JWT.encode(payload, secret, "HS256")
  end

  def self.scopes_for(user)
    scopes = []
    scopes << "bearclaw.operator" if user.operator? || user.admin?
    scopes << "bearclaw.admin" if user.admin?
    scopes.join(" ")
  end

  def self.secret
    ENV["TARDIGRADE_JWT_SECRET"].presence || default_secret
  end

  def self.issuer
    ENV["TARDIGRADE_JWT_ISSUER"].presence || DEFAULT_ISSUER
  end

  def self.audience
    ENV["TARDIGRADE_JWT_AUDIENCE"].presence || DEFAULT_AUDIENCE
  end

  def self.device_id
    ENV["TARDIGRADE_DEVICE_ID"].presence || DEFAULT_DEVICE_ID
  end

  def self.ttl_seconds
    ENV.fetch("TARDIGRADE_JWT_TTL_SECONDS", DEFAULT_TTL_SECONDS).to_i
  end

  def self.default_secret
    return "test-tardigrade-secret" if Rails.env.test?
    return "dev-tardigrade-secret" if Rails.env.development?

    raise ConfigurationError, "TARDIGRADE_JWT_SECRET is not configured"
  end
end
