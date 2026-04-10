module Home
  class DashboardController < ApplicationController
    before_action -> { require_role(:viewer, :operator, :admin) }
    before_action :require_home_membership

    def index
      unless current_home
        redirect_to root_path, alert: "No household has been set up yet. Ask an admin to run db:seed." and return
      end

      sync_koala_inventory  if current_user.admin?
      sync_polar_inventory  if current_user.admin?
      sync_kodiak_inventory if current_user.admin?
      sync_ursa_inventory   if current_user.admin?

      provisioner = Home::DashboardProvisioner.new(user: current_home.owner)
      @dashboards = provisioner.all_dashboards
      @dashboard  = provisioner.dashboard_named(params[:dashboard]) || @dashboards.first
      @dashboard  = Dashboard.includes(dashboard_tiles: { dashboard_widgets: { device_capability: :device } }).find(@dashboard.id)
      @available_capabilities = DeviceCapability.joins(:device).includes(:device).where(devices: { user_id: current_home.owner_id }).order("devices.name ASC", "device_capabilities.name ASC")
      @service_providers = ServiceProvider.includes(service_connections: { devices: :device_capabilities }).order(:name)
      @service_connections = ServiceConnection.includes(:service_provider).order(:name)
      @devices = Device.for_home(current_home).includes(:service_connection, :device_capabilities).order(:name)
      @edit_mode = params[:edit] == "1"
    end

    private

    def sync_koala_inventory
      return if ENV["KOALA_URL"].blank?

      Home::KoalaDeviceSync.new(
        client: koala_client,
        base_url: ENV["KOALA_URL"],
        user: current_home.owner
      ).sync!
    rescue StandardError => e
      @koala_error = e.message
    end

    def sync_polar_inventory
      return if ENV["POLAR_URL"].blank? || ENV["POLAR_TOKEN"].blank?

      Home::PolarDeviceSync.new(
        client: polar_client,
        base_url: ENV["POLAR_URL"],
        user: current_home.owner
      ).sync!
    rescue StandardError => e
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

    def sync_kodiak_inventory
      return if ENV["KODIAK_URL"].blank? || ENV["KODIAK_TOKEN"].blank?

      Home::KodiakDeviceSync.new(
        client: kodiak_client,
        base_url: ENV["KODIAK_URL"],
        user: current_home.owner
      ).sync!
    rescue StandardError => e
      @kodiak_error = e.message
    end

    def sync_ursa_inventory
      return if ENV["URSA_URL"].blank? || ENV["URSA_TOKEN"].blank?

      Home::UrsaDeviceSync.new(
        client: ursa_client,
        base_url: ENV["URSA_URL"],
        user: current_home.owner
      ).sync!
    rescue StandardError => e
      @ursa_error = e.message
    end

    def kodiak_client
      @kodiak_client ||= KodiakClient.new(
        base_url: ENV.fetch("KODIAK_URL", "http://192.168.86.53:6702"),
        token: ENV.fetch("KODIAK_TOKEN", "")
      )
    end

    def ursa_client
      @ursa_client ||= UrsaClient.new(
        base_url: ENV["URSA_URL"],
        token: ENV["URSA_TOKEN"],
        actor: "bearclaw-dashboard"
      )
    end
  end
end
