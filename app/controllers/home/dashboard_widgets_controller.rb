module Home
  class DashboardWidgetsController < ApplicationController
    before_action -> { require_role(:operator, :admin) }
    before_action :set_dashboard
    before_action :set_tile, only: [ :create ]
    before_action :set_widget, only: [ :update, :destroy ]

    def create
      capability = DeviceCapability.find(widget_params.fetch(:device_capability_id))
      @tile.dashboard_widgets.create!(
        device_capability: capability,
        widget_type: widget_type_for(capability),
        title: widget_params[:title],
        position: @tile.dashboard_widgets.maximum(:position).to_i + 1,
        settings: widget_settings
      )

      redirect_to home_root_path(edit: 1), notice: "Widget added."
    rescue KeyError, ActiveRecord::RecordNotFound, ActiveRecord::RecordInvalid => e
      message = e.respond_to?(:record) ? e.record.errors.full_messages.to_sentence : e.message
      redirect_to home_root_path(edit: 1), alert: message
    end

    def update
      capability = @widget.device_capability
      if widget_params[:device_capability_id].present?
        capability = DeviceCapability.find(widget_params[:device_capability_id])
      end

      @widget.update!(
        device_capability: capability,
        widget_type: widget_type_for(capability),
        title: widget_params[:title],
        position: widget_params[:position].presence || @widget.position,
        settings: @widget.settings_hash.merge(widget_settings)
      )

      redirect_to home_root_path(edit: 1), notice: "Widget updated."
    rescue ActiveRecord::RecordNotFound, ActiveRecord::RecordInvalid => e
      message = e.respond_to?(:record) ? e.record.errors.full_messages.to_sentence : e.message
      redirect_to home_root_path(edit: 1), alert: message
    end

    def destroy
      @widget.destroy!
      redirect_to home_root_path(edit: 1), notice: "Widget removed."
    end

    private

    def set_dashboard
      @dashboard = Dashboard.fetch_or_create_for!(user: current_user, context: :home, name: "Home Dashboard")
    end

    def set_tile
      @tile = @dashboard.dashboard_tiles.find(params[:dashboard_tile_id])
    end

    def set_widget
      @widget = DashboardWidget.joins(:dashboard_tile).where(dashboard_tiles: { dashboard_id: @dashboard.id }).find(params[:id])
    end

    def widget_type_for(capability)
      requested = widget_params[:widget_type].presence
      return requested if requested.present? && capability.allowed_widget_types.include?(requested)

      capability.default_widget_type
    end

    def widget_settings
      interval = widget_params[:refresh_interval_seconds].to_i
      return {} unless interval.positive?

      { "refresh_interval_seconds" => interval }
    end

    def widget_params
      params.require(:dashboard_widget).permit(:title, :widget_type, :position, :device_capability_id, :refresh_interval_seconds)
    end
  end
end
