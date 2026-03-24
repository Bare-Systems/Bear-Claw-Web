class ServiceProvider < ApplicationRecord
  PROVIDER_TYPES = %w[integration physical network hybrid].freeze

  has_many :service_connections, dependent: :destroy
  has_many :devices, through: :service_connections

  validates :key, presence: true, uniqueness: true
  validates :name, presence: true
  validates :provider_type, presence: true, inclusion: { in: PROVIDER_TYPES }
  validates :description, length: { maximum: 500 }, allow_blank: true

  def settings_hash
    settings.is_a?(Hash) ? settings : {}
  end
end
