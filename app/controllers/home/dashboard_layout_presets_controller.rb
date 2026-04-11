module Home
  class DashboardLayoutPresetsController < ApplicationController
    before_action -> { require_role(:operator, :admin) }
    before_action :set_dashboard

    def create
      store.save!(name: preset_name)
      redirect_to home_root_path(edit: 1, dashboard: @dashboard.name), notice: "#{preset_name} saved."
    rescue ActiveRecord::RecordInvalid
      redirect_to home_root_path(edit: 1, dashboard: @dashboard.name), alert: "Preset name can't be blank."
    end

    def apply
      preset = store.fetch(name: params[:name])
      raise ActiveRecord::RecordNotFound if preset.blank?

      history.push!(snapshot: history.snapshot(label: "#{preset.fetch("name")} applied"))
      Home::DashboardLayoutPresetApplier.new(dashboard: @dashboard, preset: preset).apply!
      redirect_to home_root_path(edit: 1, dashboard: @dashboard.name), notice: "#{preset.fetch("name")} applied."
    end

    def destroy
      deleted = store.delete!(name: params[:name])
      raise ActiveRecord::RecordNotFound unless deleted

      redirect_to home_root_path(edit: 1, dashboard: @dashboard.name), notice: "#{params[:name]} deleted."
    end

    private

    def set_dashboard
      @dashboard = Dashboard.for_context(:home).where(user: current_user).find(params[:dashboard_id])
      @dashboard = Home::DashboardDensityUpgrader.new(dashboard: @dashboard).upgrade!
    end

    def store
      @store ||= Home::DashboardLayoutPresetStore.new(dashboard: @dashboard)
    end

    def history
      @history ||= Home::DashboardLayoutHistory.new(dashboard: @dashboard)
    end

    def preset_name
      params.require(:layout_preset).fetch(:name).to_s.strip
    end
  end
end
