class Dashboard < ApplicationRecord
  CONTEXTS = %w[home agent security admin].freeze

  belongs_to :user

  has_many :dashboard_tiles, -> { order(:row, :column, :position, :id) }, dependent: :destroy
  has_many :dashboard_widgets, through: :dashboard_tiles

  validates :name, presence: true
  validates :context, presence: true, inclusion: { in: CONTEXTS }

  scope :for_context, ->(context_name) { where(context: context_name.to_s) }

  def self.fetch_or_create_for!(user:, context:, name: nil)
    find_or_create_by!(user: user, context: context.to_s, name: name || "#{context.to_s.humanize} Dashboard") do |dashboard|
      dashboard.settings = { "columns" => 4 }
    end
  end

  def settings_hash
    settings.is_a?(Hash) ? settings : {}
  end

  def columns
    value = settings_hash["columns"].to_i
    value.positive? ? value : 4
  end
end
