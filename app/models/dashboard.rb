class Dashboard < ApplicationRecord
  CONTEXTS = %w[home agent security admin].freeze
  DEFAULT_COLUMNS = 4
  LEGACY_DENSE_COLUMNS = 8
  BASE_ROW_UNIT_REM = 10.0

  belongs_to :user

  has_many :dashboard_tiles, -> { order(:row, :column, :position, :id) }, dependent: :destroy
  has_many :dashboard_widgets, through: :dashboard_tiles

  validates :name, presence: true
  validates :context, presence: true, inclusion: { in: CONTEXTS }

  scope :for_context, ->(context_name) { where(context: context_name.to_s) }

  def self.fetch_or_create_for!(user:, context:, name: nil)
    find_or_create_by!(user: user, context: context.to_s, name: name || "#{context.to_s.humanize} Dashboard") do |dashboard|
      dashboard.settings = { "columns" => DEFAULT_COLUMNS }
    end
  end

  def settings_hash
    settings.is_a?(Hash) ? settings : {}
  end

  def columns
    value = settings_hash["columns"].to_i
    value.positive? ? value : DEFAULT_COLUMNS
  end

  def density_scale
    [ columns.to_f / LEGACY_DENSE_COLUMNS, 1.0 ].max
  end

  def row_unit_rem
    (BASE_ROW_UNIT_REM / density_scale).round(4)
  end

  def default_tile_span(base_span: 2)
    [ (base_span * density_scale).round, 1 ].max.clamp(1, columns)
  end

  # Camera feeds are landscape (default 16:9). With square grid cells, a tile's
  # pixel aspect ratio equals width:height, so to hug a feed of `feed_aspect`
  # (width/height) the tile height in grid units is width / feed_aspect.
  CAMERA_FEED_ASPECT = 16.0 / 9.0

  def default_camera_tile_height(base_width: 2, feed_aspect: CAMERA_FEED_ASPECT)
    width = default_tile_span(base_span: base_width)
    camera_height_for_width(width, feed_aspect: feed_aspect)
  end

  def camera_height_for_width(width, feed_aspect: CAMERA_FEED_ASPECT)
    aspect = feed_aspect.to_f
    aspect = CAMERA_FEED_ASPECT unless aspect.positive?
    [ (width.to_i / aspect).round, 1 ].max.clamp(1, DashboardTile::MAX_HEIGHT)
  end

  def layout_presets
    presets = settings_hash["layout_presets"]
    presets.is_a?(Array) ? presets.select { |preset| preset.is_a?(Hash) } : []
  end
end
