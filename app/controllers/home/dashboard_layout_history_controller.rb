module Home
  class DashboardLayoutHistoryController < ApplicationController
    before_action -> { require_role(:operator, :admin) }
    before_action :set_dashboard

    def undo
      snapshot = layout_history.undo!
      if snapshot.present?
        redirect_to home_root_path(edit: 1, dashboard: @dashboard.name), notice: "Last layout change undone."
      else
        redirect_to home_root_path(edit: 1, dashboard: @dashboard.name), alert: "No layout history is available yet."
      end
    end

    def reset
      Home::DashboardResetter.new(dashboard: @dashboard, user: @dashboard.user).restore_defaults!
      redirect_to home_root_path(edit: 1, dashboard: @dashboard.name), notice: "Dashboard restored to defaults."
    end

    private

    def set_dashboard
      @dashboard = Dashboard.for_context(:home).where(user: current_user).find(params[:dashboard_id])
      @dashboard = Home::DashboardDensityUpgrader.new(dashboard: @dashboard).upgrade!
    end

    def layout_history
      @layout_history ||= Home::DashboardLayoutHistory.new(dashboard: @dashboard)
    end
  end
end
