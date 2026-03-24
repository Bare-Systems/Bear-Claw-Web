class DashboardTile < ApplicationRecord
  belongs_to :dashboard

  has_many :dashboard_widgets, -> { order(:position, :id) }, dependent: :destroy

  validates :row, :column, :width, :height, :position, numericality: { only_integer: true, greater_than: 0 }
  validates :width, inclusion: { in: 1..4 }
  validates :height, inclusion: { in: 1..3 }

  def settings_hash
    settings.is_a?(Hash) ? settings : {}
  end

  def display_title
    title.presence || dashboard_widgets.first&.display_title || "Tile #{id}"
  end
end
