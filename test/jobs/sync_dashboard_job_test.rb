require "test_helper"
require "securerandom"

class SyncDashboardJobTest < ActiveJob::TestCase
  test "syncs and broadcasts the household owner's dashboard for non-owner members" do
    token = SecureRandom.hex(6)
    owner = User.create!(
      email: "sync-dashboard-owner-#{token}@example.com",
      google_uid: "sync-dashboard-owner-#{token}",
      name: "Owner #{token}",
      role: :operator
    )
    viewer = User.create!(
      email: "sync-dashboard-viewer-#{token}@example.com",
      google_uid: "sync-dashboard-viewer-#{token}",
      name: "Viewer #{token}",
      role: :viewer
    )

    household = Household.create!(name: "Household #{token}", owner: owner)
    HouseholdMembership.create!(household: household, user: owner, role: "owner")
    HouseholdMembership.create!(household: household, user: viewer, role: "member")

    dashboard = Dashboard.create!(user: owner, context: "home", name: "Home Dashboard", settings: { "columns" => 4 })
    tile = dashboard.dashboard_tiles.create!(title: "Humidity", row: 1, column: 1, width: 2, height: 2, position: 1, settings: {})

    provider = ServiceProvider.create!(key: "polar-#{token}", name: "Polar", provider_type: "network")
    connection = ServiceConnection.create!(
      service_provider: provider,
      key: "polar-#{token}",
      name: "Polar",
      adapter: "polar",
      credential_strategy: "environment",
      status: "online",
      base_url: "http://polar.test"
    )
    device = Device.create!(
      service_connection: connection,
      user: owner,
      key: "polar-device-#{token}",
      name: "Airthings",
      category: "sensor",
      source_kind: "network",
      source_identifier: "airthings-#{token}",
      status: "available"
    )
    capability = DeviceCapability.create!(
      device: device,
      key: "metric_humidity",
      name: "Humidity",
      capability_type: "sensor",
      configuration: { "metric" => "humidity", "scope" => "indoor" },
      state: {
        "value" => 37,
        "unit" => "%RH",
        "quality" => "good",
        "status" => "available",
        "last_seen_at" => Time.current.iso8601
      }
    )
    widget = tile.dashboard_widgets.create!(device_capability: capability, widget_type: "air_quality_stat", position: 1, settings: {})

    broadcasts = []
    job = SyncDashboardJob.new

    original_broadcast = ActionCable.server.method(:broadcast)
    ActionCable.server.define_singleton_method(:broadcast) do |stream, payload|
      broadcasts << [ stream, payload ]
    end

    original_sync_koala = job.method(:sync_koala)
    original_sync_polar = job.method(:sync_polar)
    original_sync_govee = job.method(:sync_govee)
    job.define_singleton_method(:sync_koala) { |_dashboard_owner| nil }
    job.define_singleton_method(:sync_polar) { |_dashboard_owner| nil }
    job.define_singleton_method(:sync_govee) { nil }

    begin
      job.perform(user_id: viewer.id)
    ensure
      job.define_singleton_method(:sync_koala) do |*args, **kwargs, &blk|
        original_sync_koala.call(*args, **kwargs, &blk)
      end
      job.define_singleton_method(:sync_polar) do |*args, **kwargs, &blk|
        original_sync_polar.call(*args, **kwargs, &blk)
      end
      job.define_singleton_method(:sync_govee) do |*args, **kwargs, &blk|
        original_sync_govee.call(*args, **kwargs, &blk)
      end
      ActionCable.server.define_singleton_method(:broadcast) do |*args, **kwargs, &blk|
        original_broadcast.call(*args, **kwargs, &blk)
      end
    end

    assert_equal 1, broadcasts.size
    stream, payload = broadcasts.first
    assert_equal "home_dashboard:#{viewer.id}", stream
    assert_includes payload.fetch(:turbo_streams), "widget-#{widget.id}"
    assert_includes payload.fetch(:turbo_streams), "Synced"
  end
end
