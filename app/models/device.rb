class Device < ApplicationRecord
  CATEGORIES = %w[dvr camera switch sensor network_service custom].freeze
  SOURCE_KINDS = %w[physical network virtual].freeze
  STATUSES = %w[available degraded unavailable unknown].freeze

  belongs_to :user, optional: true
  belongs_to :service_connection, optional: true
  belongs_to :parent_device, class_name: "Device", optional: true

  has_many :child_devices, class_name: "Device", foreign_key: :parent_device_id, dependent: :destroy, inverse_of: :parent_device
  has_many :device_capabilities, dependent: :destroy
  has_many :dashboard_widgets, through: :device_capabilities

  delegate :service_provider, to: :service_connection, allow_nil: true

  validates :key, presence: true, uniqueness: true
  validates :name, presence: true
  validates :category, presence: true, inclusion: { in: CATEGORIES }
  validates :source_kind, presence: true, inclusion: { in: SOURCE_KINDS }
  validates :status, presence: true, inclusion: { in: STATUSES }

  scope :roots,    -> { where(parent_device_id: nil) }
  scope :for_home, ->(home) { where(user_id: home.owner_id) }

  def metadata_hash
    metadata.is_a?(Hash) ? metadata : {}
  end

  def source_label
    service_provider&.name.presence || source_kind.humanize
  end
end
