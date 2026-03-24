module Home
  class DashboardController < ApplicationController
    before_action -> { require_role(:viewer, :operator, :admin) }
    before_action :require_home_membership

    def index
      unless current_home
        redirect_to root_path, alert: "No household has been set up yet. Ask an admin to run db:seed." and return
      end

      sync_koala_inventory if current_user.admin?
      sync_polar_inventory if current_user.admin?
      @dashboard = Home::DashboardProvisioner.new(user: current_home.owner).home_dashboard
      @dashboard = Dashboard.includes(dashboard_tiles: { dashboard_widgets: { device_capability: :device } }).find(@dashboard.id)
      @available_capabilities = DeviceCapability.joins(:device).includes(:device).where(devices: { user_id: current_home.owner_id }).order("devices.name ASC", "device_capabilities.name ASC")
      @service_providers = ServiceProvider.includes(service_connections: { devices: :device_capabilities }).order(:name)
      @service_connections = ServiceConnection.includes(:service_provider).order(:name)
      @devices = Device.for_home(current_home).includes(:service_connection, :device_capabilities).order(:name)
      @edit_mode = params[:edit] == "1"
    end

    private

    def sync_koala_inventory
      Home::KoalaDeviceSync.new(
        client: koala_client,
        base_url: ENV["KOALA_URL"],
        user: current_home.owner
      ).sync!
    rescue KoalaClient::Error => e
      @koala_error = e.message
    end

    def sync_polar_inventory
      return if ENV["POLAR_URL"].blank? || ENV["POLAR_TOKEN"].blank?

      Home::PolarDeviceSync.new(
        client: polar_client,
        base_url: ENV["POLAR_URL"],
        user: current_home.owner
      ).sync!
    rescue PolarClient::Error => e
      @polar_error = e.message
    end

    def koala_client
      @koala_client ||= KoalaClient.new(
        base_url: ENV["KOALA_URL"],
        token: ENV["KOALA_TOKEN"]
      )
    end

    def polar_client
      @polar_client ||= PolarClient.new(
        base_url: ENV["POLAR_URL"],
        token: ENV["POLAR_TOKEN"]
      )
    end
  end
end
