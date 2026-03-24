# Performs an on-demand sync for a user-configured integration immediately
# after credentials are saved on the Integrations settings page.
#
# Supports:
#   govee → Home::GoveeDeviceSync via GoveeClient
#   (airthings syncs are handled by Polar; custom integrations are passive)
class SyncIntegrationJob < ApplicationJob
  queue_as :default

  def perform(provider_key:)
    integration = Integration.find_by(provider_key: provider_key)
    return Rails.logger.warn("[SyncIntegrationJob] No integration found for #{provider_key}") unless integration

    case provider_key
    when "govee"
      sync_govee(integration)
    else
      Rails.logger.info("[SyncIntegrationJob] No sync handler for #{provider_key} — skipping")
    end
  rescue => e
    Rails.logger.error("[SyncIntegrationJob] #{provider_key} sync failed: #{e.message}")
    integration&.update(status: "error", last_error: e.message)
  end

  private

  def sync_govee(integration)
    creds  = integration.credentials
    client = GoveeClient.new(api_key: creds["api_key"].to_s)

    Home::GoveeDeviceSync.new(client: client, integration: integration).sync!

    integration.update!(status: "connected", last_error: nil, last_verified_at: Time.current)
  rescue GoveeClient::Error => e
    integration.update!(status: "error", last_error: e.message)
    raise
  end
end
