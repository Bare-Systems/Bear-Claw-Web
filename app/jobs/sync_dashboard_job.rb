require "cgi"

# Runs Koala + Polar syncs in the background and pushes Turbo Stream
# fragments over the DashboardChannel so live sensor widgets update in
# place without a page reload.
#
# This job is enqueued by DashboardChannel#sync, which the browser
# calls every 30 s while the dashboard tab is open.  When the tab is
# closed the Stimulus controller stops sending sync messages, so no
# unnecessary network calls are made.
class SyncDashboardJob < ApplicationJob
  queue_as :default

  # Widget types whose partials are safe to render off-request (no URL helpers).
  BROADCASTABLE_TYPES = %w[air_quality_stat sensor_stat].freeze

  def perform(user_id:)
    user = User.find_by(id: user_id)
    return Rails.logger.warn("[SyncDashboardJob] Unknown user #{user_id}") unless user

    dashboard = Dashboard.where(user: user, context: "home").first
    return Rails.logger.warn("[SyncDashboardJob] No home dashboard for user #{user_id}") unless dashboard

    errors = run_syncs

    dashboard = Dashboard.includes(
      dashboard_tiles: { dashboard_widgets: { device_capability: :device } }
    ).find(dashboard.id)

    broadcast_updates(dashboard, user, errors)
  end

  private

  # ── Sync ─────────────────────────────────────────────────────────────────

  def run_syncs
    errors = {}

    begin
      sync_koala
    rescue KoalaClient::Error => e
      Rails.logger.warn("[SyncDashboardJob] Koala: #{e.message}")
      errors[:koala] = e.message
    end

    begin
      sync_polar
    rescue PolarClient::Error => e
      Rails.logger.warn("[SyncDashboardJob] Polar: #{e.message}")
      errors[:polar] = e.message
    end

    begin
      sync_govee
    rescue GoveeClient::Error => e
      Rails.logger.warn("[SyncDashboardJob] Govee: #{e.message}")
      errors[:govee] = e.message
    end

    errors
  end

  def sync_koala
    return if ENV["KOALA_URL"].blank?

    Home::KoalaDeviceSync.new(
      client:   KoalaClient.new(base_url: ENV["KOALA_URL"], token: ENV["KOALA_TOKEN"]),
      base_url: ENV["KOALA_URL"]
    ).sync!
  end

  def sync_polar
    return if ENV["POLAR_URL"].blank? || ENV["POLAR_TOKEN"].blank?

    Home::PolarDeviceSync.new(
      client:   PolarClient.new(base_url: ENV["POLAR_URL"], token: ENV["POLAR_TOKEN"]),
      base_url: ENV["POLAR_URL"]
    ).sync!
  end

  def sync_govee
    integration = Integration.find_by(provider_key: "govee", status: "connected")
    return unless integration

    api_key = integration.credentials["api_key"].to_s
    return if api_key.blank?

    Home::GoveeDeviceSync.new(
      client:      GoveeClient.new(api_key: api_key),
      integration: integration
    ).sync!
  end

  # ── Broadcast ─────────────────────────────────────────────────────────────

  def broadcast_updates(dashboard, user, errors)
    streams = widget_streams(dashboard) + [ status_stream(errors) ]

    ActionCable.server.broadcast(
      "home_dashboard:#{user.id}",
      { turbo_streams: streams.join("\n") }
    )
  end

  def widget_streams(dashboard)
    dashboard.dashboard_tiles.flat_map do |tile|
      tile.dashboard_widgets.filter_map do |widget|
        next unless BROADCASTABLE_TYPES.include?(widget.widget_type)
        next unless widget.device_capability

        widget.device_capability.reload
        html = ApplicationController.render(
          partial: "home/widgets/#{widget.widget_type}",
          locals:  { widget: widget }
        )
        turbo_replace("widget-#{widget.id}", html)
      rescue => e
        Rails.logger.warn("[SyncDashboardJob] Failed to render widget #{widget.id}: #{e.message}")
        nil
      end
    end
  end

  # Renders the small "Synced 3:47 PM" / "Koala error · 3:47 PM" blurb
  # that sits next to the dashboard title.
  def status_stream(errors)
    time = Time.current.strftime("%-I:%M %p")

    html = if errors.empty?
      %(<span class="text-xs text-gray-500">Synced #{h time}</span>)
    else
      providers = errors.keys.map(&:to_s).map(&:capitalize).join(" &amp; ")
      %(<span class="text-xs text-amber-500">#{providers} error · #{h time}</span>)
    end

    turbo_replace("dashboard-sync-status", html)
  end

  # ── Helpers ───────────────────────────────────────────────────────────────

  def turbo_replace(target, inner_html)
    %(<turbo-stream action="replace" target="#{target}"><template>#{inner_html}</template></turbo-stream>)
  end

  def h(str)
    CGI.escapeHTML(str.to_s)
  end
end
