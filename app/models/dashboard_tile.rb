class DashboardTile < ApplicationRecord
  MAX_HEIGHT = 6
  DEFAULT_SPAN = 2

  belongs_to :dashboard

  has_many :dashboard_widgets, -> { order(:position, :id) }, dependent: :destroy

  validates :row, :column, :width, :height, :position, numericality: { only_integer: true, greater_than: 0 }
  validate :width_within_dashboard_bounds
  validate :height_within_bounds

  def settings_hash
    settings.is_a?(Hash) ? settings : {}
  end

  def display_title
    title.presence || dashboard_widgets.first&.display_title || "Tile #{id}"
  end

  def section_name
    settings_hash["section"].to_s.strip.presence || "General"
  end

  private

  def width_within_dashboard_bounds
    return if dashboard.blank? || width.blank?
    return if width <= dashboard.columns

    errors.add(:width, "must be less than or equal to #{dashboard.columns}")
  end

  def height_within_bounds
    return if height.blank?
    return if height <= MAX_HEIGHT

    errors.add(:height, "must be less than or equal to #{MAX_HEIGHT}")
  end
end
