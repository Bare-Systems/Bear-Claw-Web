module Settings
  class IntegrationsController < Settings::BaseController
    before_action :set_integration, only: [ :update, :destroy ]

    def index
      @providers     = Home::ProviderRegistry.all
      @integrations  = Integration.all.index_by(&:provider_key)
      @polar_online  = ServiceConnection.find_by(key: "polar")&.status.in?(%w[online degraded])
    end

    def create
      provider_key = params.require(:provider_key)
      provider     = Home::ProviderRegistry.find(provider_key)

      return redirect_to settings_integrations_path, alert: "Unknown provider." unless provider

      @integration = Integration.find_or_initialize_by(provider_key: provider_key)
      @integration.name        = provider[:name]
      @integration.status      = "connected"
      @integration.credentials = extract_credentials(provider)
      @integration.last_error  = nil

      if @integration.save
        enqueue_sync(provider_key)
        redirect_to settings_integrations_path,
          notice: "#{provider[:name]} connected successfully."
      else
        @providers    = Home::ProviderRegistry.all
        @integrations = Integration.all.index_by(&:provider_key)
        render :index, status: :unprocessable_entity
      end
    end

    def update
      provider = @integration.provider

      @integration.credentials = extract_credentials(provider, existing: @integration.credentials)
      @integration.status      = "connected"
      @integration.last_error  = nil

      if @integration.save
        enqueue_sync(@integration.provider_key)
        redirect_to settings_integrations_path,
          notice: "#{@integration.display_name} updated."
      else
        @providers    = Home::ProviderRegistry.all
        @integrations = Integration.all.index_by(&:provider_key)
        render :index, status: :unprocessable_entity
      end
    end

    def destroy
      name = @integration.display_name
      @integration.destroy!
      redirect_to settings_integrations_path, notice: "#{name} disconnected."
    end

    private

    def set_integration
      @integration = Integration.find(params[:id])
    end

    # Build credential hash from params, keyed by each field's :key.
    # On update, blank values are merged over the existing credentials so that
    # "Leave blank to keep existing" actually works.
    def extract_credentials(provider, existing: {})
      fields = Array(provider[:credential_fields]).map { |f| f[:key] }
      incoming = params.permit(*fields).to_h
      existing.merge(incoming.reject { |_, v| v.blank? })
    end

    def enqueue_sync(provider_key)
      SyncIntegrationJob.perform_later(provider_key: provider_key)
    end
  end
end
