class DeviceCapability < ApplicationRecord
  CAPABILITY_TYPES = %w[camera_feed switch sensor status finance].freeze

  belongs_to :device

  has_many :dashboard_widgets, dependent: :nullify

  validates :key, presence: true, uniqueness: { scope: :device_id }
  validates :name, presence: true
  validates :capability_type, presence: true, inclusion: { in: CAPABILITY_TYPES }

  scope :with_devices, -> { includes(:device) }

  def configuration_hash
    configuration.is_a?(Hash) ? configuration : {}
  end

  def state_hash
    state.is_a?(Hash) ? state : {}
  end

  def allowed_widget_types
    Home::CapabilityWidgetCatalog.allowed_widgets_for(capability_type)
  end

  def default_widget_type
    Home::CapabilityWidgetCatalog.default_widget_type_for(capability_type)
  end

  def camera_id
    configuration_hash["camera_id"].presence || state_hash["camera_id"].presence
  end

  def status_label
    state_hash["status"].presence || device.status.presence || "unknown"
  end

  def current_value
    state_hash["value"]
  end

  def unit
    state_hash["unit"]
  end

  def switch_on?
    ActiveModel::Type::Boolean.new.cast(current_value)
  end
end
