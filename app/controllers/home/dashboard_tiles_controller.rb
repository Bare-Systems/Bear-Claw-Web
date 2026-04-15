module Home
  class DashboardTilesController < ApplicationController
    before_action -> { require_role(:operator, :admin) }
    before_action :set_dashboard
    before_action :set_tile, only: [ :update, :destroy ]

    def create
      history_snapshot = layout_history.snapshot(label: "Tile added")
      position = @dashboard.dashboard_tiles.maximum(:position).to_i + 1
      row, column = default_grid_position(position)

      tile = @dashboard.dashboard_tiles.create!(
        tile_attributes(default_row: row, default_column: column, position: position)
      )
      normalize_layout!(anchor_tile: tile)
      layout_history.push!(snapshot: history_snapshot)

      redirect_to home_root_path(edit: 1), notice: "Tile added."
    rescue ActiveRecord::RecordInvalid => e
      redirect_to home_root_path(edit: 1), alert: e.record.errors.full_messages.to_sentence
    end

    def update
      history_snapshot = layout_history.snapshot(label: "Tile updated")
      @tile.update!(tile_attributes(existing_tile: @tile))
      normalize_layout!(anchor_tile: @tile)
      layout_history.push!(snapshot: history_snapshot)

      respond_to do |format|
        format.html { redirect_to home_root_path(edit: 1), notice: "Tile updated." }
        format.json { render json: { tiles: serialized_tiles } }
      end
    rescue ActiveRecord::RecordInvalid => e
      respond_to do |format|
        format.html { redirect_to home_root_path(edit: 1), alert: e.record.errors.full_messages.to_sentence }
        format.json { render json: { error: e.record.errors.full_messages.to_sentence }, status: :unprocessable_entity }
      end
    end

    def apply_pack
      pack = quick_add_pack_catalog.pack(params[:pack_key])
      raise ActiveRecord::RecordNotFound if pack.blank?

      history_snapshot = layout_history.snapshot(label: "#{pack.label} added")
      result = Home::DashboardQuickAddPackApplier.new(dashboard: @dashboard, pack: pack).apply!

      if result.created_count.positive?
        layout_history.push!(snapshot: history_snapshot)
        redirect_to home_root_path(edit: 1, dashboard: @dashboard.name), notice: "#{pack.label} added."
      else
        redirect_to home_root_path(edit: 1, dashboard: @dashboard.name), alert: "#{pack.label} is already applied to this dashboard."
      end
    rescue ActiveRecord::RecordInvalid => e
      redirect_to home_root_path(edit: 1, dashboard: @dashboard.name), alert: e.record.errors.full_messages.to_sentence
    end

    def destroy
      history_snapshot = layout_history.snapshot(label: "Tile removed")
      @tile.destroy!
      normalize_layout!
      layout_history.push!(snapshot: history_snapshot)
      redirect_to home_root_path(edit: 1), notice: "Tile removed."
    end

    private

    def default_grid_position(position)
      span = DashboardTile::DEFAULT_SPAN
      slots_per_row = [ @dashboard.columns / span, 1 ].max
      row = ((position - 1) / slots_per_row) * span + 1
      column = (((position - 1) % slots_per_row) * span) + 1

      [ row, column ]
    end

    def set_dashboard
      @dashboard = if params[:dashboard_id].present?
        Dashboard.for_context(:home).where(user: current_user).find(params[:dashboard_id])
      else
        Dashboard.fetch_or_create_for!(user: current_user, context: :home, name: "Home Dashboard")
      end
      @dashboard = Home::DashboardDensityUpgrader.new(dashboard: @dashboard).upgrade!
    end

    def quick_add_pack_catalog
      @quick_add_pack_catalog ||= Home::DashboardQuickAddPackCatalog.new(
        capabilities: DeviceCapability
          .joins(:device)
          .includes(device: { service_connection: :service_provider })
          .where(devices: { user_id: current_user.id })
          .order("devices.name ASC", "device_capabilities.name ASC")
      )
    end

    def layout_history
      @layout_history ||= Home::DashboardLayoutHistory.new(dashboard: @dashboard)
    end

    def set_tile
      @tile = @dashboard.dashboard_tiles.find(params[:id])
    end

    def normalize_layout!(anchor_tile: nil)
      Home::DashboardLayoutNormalizer.new(dashboard: @dashboard).normalize!(anchor_tile: anchor_tile)
    end

    def serialized_tiles
      @dashboard.dashboard_tiles.order(:position, :id).map do |tile|
        {
          id: tile.id,
          section: tile.section_name,
          row: tile.row,
          column: tile.column,
          width: tile.width,
          height: tile.height,
          position: tile.position
        }
      end
    end

    def tile_attributes(default_row: nil, default_column: nil, position: nil, existing_tile: nil)
      existing_settings = existing_tile&.settings_hash || {}

      {
        title: tile_params[:title].presence || existing_tile&.title || "Custom Tile",
        row: tile_params[:row].presence || existing_tile&.row || default_row,
        column: tile_params[:column].presence || existing_tile&.column || default_column,
        width: tile_params[:width].presence || existing_tile&.width || DashboardTile::DEFAULT_SPAN,
        height: tile_params[:height].presence || existing_tile&.height || DashboardTile::DEFAULT_SPAN,
        position: position || existing_tile&.position,
        settings: tile_settings(existing_settings)
      }
    end

    def tile_settings(existing_settings)
      settings = existing_settings.deep_dup
      section = normalized_section(tile_params[:section])
      section.present? ? settings.merge("section" => section) : settings.except("section")
    end

    def normalized_section(value)
      value.to_s.strip.presence
    end

    def tile_params
      params.require(:dashboard_tile).permit(:title, :section, :row, :column, :width, :height)
    end
  end
end
