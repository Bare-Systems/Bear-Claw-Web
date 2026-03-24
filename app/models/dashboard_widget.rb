class DashboardWidget < ApplicationRecord
  WIDGET_TYPES = %w[camera_feed status_badge switch_control sensor_stat air_quality_stat].freeze

  belongs_to :dashboard_tile
  belongs_to :device_capability, optional: true

  delegate :device, to: :device_capability, allow_nil: true

  validates :widget_type, presence: true, inclusion: { in: WIDGET_TYPES }
  validates :position, numericality: { only_integer: true, greater_than: 0 }
  validate :widget_type_allowed_for_capability

  def settings_hash
    settings.is_a?(Hash) ? settings : {}
  end

  def display_title
    title.presence || device_capability&.name || widget_type.humanize
  end

  def refresh_interval_seconds
    value = settings_hash["refresh_interval_seconds"].to_i
    value.positive? ? value : 4
  end

  private

  def widget_type_allowed_for_capability
    return if device_capability.blank?
    return if device_capability.allowed_widget_types.include?(widget_type)

    errors.add(:widget_type, "is not supported for #{device_capability.capability_type.humanize.downcase}")
  end
end
