class Integration < ApplicationRecord
  STATUSES = %w[connected error disconnected].freeze

  validates :provider_key, presence: true, uniqueness: true
  validates :status, inclusion: { in: STATUSES }

  # Returns decrypted credentials as a hash, or {} if unset / undecryptable.
  def credentials
    raw = encrypted_credentials.presence
    return {} unless raw

    JSON.parse(encryptor.decrypt_and_verify(raw))
  rescue ActiveSupport::MessageEncryptor::InvalidMessage, ArgumentError, JSON::ParserError
    {}
  end

  # Encrypts and stores the given hash.
  def credentials=(hash)
    self.encrypted_credentials = hash.present? ? encryptor.encrypt_and_sign(JSON.generate(hash)) : nil
  end

  # Metadata from the static provider catalog.
  def provider
    Home::ProviderRegistry.find(provider_key)
  end

  def display_name
    name.presence || provider&.dig(:name) || provider_key.humanize
  end

  def connected?
    status == "connected"
  end

  def settings_hash
    settings.is_a?(Hash) ? settings : {}
  end

  private

  # Uses secret_key_base so no additional key management is required.
  # The first 32 bytes are used as the AES-256-GCM key.
  def encryptor
    @encryptor ||= begin
      key = Rails.application.secret_key_base.byteslice(0, 32)
      ActiveSupport::MessageEncryptor.new(key)
    end
  end
end
