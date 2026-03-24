module Home
  class DashboardTilesController < ApplicationController
    before_action -> { require_role(:operator, :admin) }
    before_action :set_dashboard
    before_action :set_tile, only: [ :update, :destroy ]

    def create
      position = @dashboard.dashboard_tiles.maximum(:position).to_i + 1
      row, column = default_grid_position(position)

      tile = @dashboard.dashboard_tiles.create!(
        title: tile_params[:title].presence || "Custom Tile",
        row: tile_params[:row].presence || row,
        column: tile_params[:column].presence || column,
        width: tile_params[:width].presence || 1,
        height: tile_params[:height].presence || 1,
        position: position
      )
      normalize_layout!(anchor_tile: tile)

      redirect_to home_root_path(edit: 1), notice: "Tile added."
    rescue ActiveRecord::RecordInvalid => e
      redirect_to home_root_path(edit: 1), alert: e.record.errors.full_messages.to_sentence
    end

    def update
      @tile.update!(tile_params)
      normalize_layout!(anchor_tile: @tile)

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

    def destroy
      @tile.destroy!
      normalize_layout!
      redirect_to home_root_path(edit: 1), notice: "Tile removed."
    end

    private

    def default_grid_position(position)
      [ ((position - 1) / 4) + 1, ((position - 1) % 4) + 1 ]
    end

    def set_dashboard
      @dashboard = Dashboard.fetch_or_create_for!(user: current_user, context: :home, name: "Home Dashboard")
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
          row: tile.row,
          column: tile.column,
          width: tile.width,
          height: tile.height,
          position: tile.position
        }
      end
    end

    def tile_params
      params.require(:dashboard_tile).permit(:title, :row, :column, :width, :height)
    end
  end
end
