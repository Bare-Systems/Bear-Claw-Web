require "jwt"

# Verifies the short-lived identity assertion minted by the BareSystems Portal
# when a user selects this device. The Portal authenticates the human and signs
# {sub,email,name,role,tenant_id,site_id}; we trust that signature (shared HS256
# secret) to establish a local session. This mirrors TardigradeIdentityToken so
# the whole stack shares one cross-service token scheme.
#
# The Portal is never in the data path — this token is the entire handoff.
class PortalIdentityToken
  class ConfigurationError < StandardError; end
  class InvalidToken < StandardError; end

  EXPECTED_ISSUER = "portal".freeze
  DEFAULT_AUDIENCE = "bearclaw-web".freeze

  def self.enabled?
    ActiveModel::Type::Boolean.new.cast(ENV["PORTAL_SSO_ENABLED"])
  end

  def self.verify(token)
    raise InvalidToken, "missing token" if token.blank?

    payload, = JWT.decode(
      token,
      secret,
      true,
      algorithm: "HS256",
      iss: EXPECTED_ISSUER,
      verify_iss: true,
      aud: audience,
      verify_aud: true,
      verify_expiration: true
    )
    payload
  rescue JWT::DecodeError => e
    raise InvalidToken, e.message
  end

  def self.secret
    ENV["PORTAL_SSO_SECRET"].presence || default_secret
  end

  def self.audience
    ENV["PORTAL_SSO_AUDIENCE"].presence || DEFAULT_AUDIENCE
  end

  def self.default_secret
    return "test-portal-sso-secret" if Rails.env.test?
    return "dev-portal-sso-secret" if Rails.env.development?

    raise ConfigurationError, "PORTAL_SSO_SECRET is not configured"
  end
end
