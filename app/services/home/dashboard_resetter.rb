module Home
  class DashboardResetter
    def initialize(dashboard:, user:)
      @dashboard = dashboard
      @user = user
    end

    def restore_defaults!
      Dashboard.transaction do
        Home::DashboardLayoutHistory.new(dashboard: @dashboard).record!(label: "Before restore defaults")
        @dashboard.update!(
          settings: @dashboard.settings_hash.merge(
            "columns" => 4,
            "density_version" => nil
          )
        )
        Home::DashboardProvisioner.new(user: @user).restore_defaults!(@dashboard)
        Home::DashboardDensityUpgrader.new(dashboard: @dashboard.reload).upgrade!
      end

      @dashboard.reload
    end
  end
end
