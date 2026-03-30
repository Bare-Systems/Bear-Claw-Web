class ServiceConnection < ApplicationRecord
  ADAPTERS = %w[koala polar govee kodiak ursa custom].freeze
  STATUSES = %w[online degraded offline error unknown].freeze

  belongs_to :service_provider

  has_many :devices, dependent: :destroy

  validates :key, presence: true, uniqueness: true
  validates :name, presence: true
  validates :adapter, presence: true, inclusion: { in: ADAPTERS }
  validates :credential_strategy, presence: true
  validates :status, presence: true, inclusion: { in: STATUSES }
  validates :base_url, length: { maximum: 500 }, allow_blank: true

  def settings_hash
    settings.is_a?(Hash) ? settings : {}
  end
end
