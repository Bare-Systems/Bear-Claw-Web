require "test_helper"
require "securerandom"

class Home::DashboardLayoutHistoryTest < ActiveSupport::TestCase
  setup do
    token = SecureRandom.hex(6)
    @user = User.create!(
      email: "dashboard-history-#{token}@example.com",
      google_uid: "dashboard-history-#{token}",
      name: "Dashboard History #{token}",
      role: :operator
    )
    @dashboard = Dashboard.fetch_or_create_for!(user: @user, context: :home, name: "History Dashboard")
    @dashboard.update!(settings: @dashboard.settings_hash.merge("columns" => 8))

    provider = ServiceProvider.create!(key: "history-provider-#{token}", name: "History Provider", provider_type: "network")
    connection = ServiceConnection.create!(
      service_provider: provider,
      key: "history-connection-#{token}",
      name: "History Connection",
      adapter: "custom",
      credential_strategy: "environment",
      status: "online",
      base_url: "http://history.test"
    )
    device = Device.create!(
      service_connection: connection,
      user: @user,
      key: "history-device-#{token}",
      name: "History Device",
      category: "network_service",
      source_kind: "network",
      source_identifier: "history",
      status: "available"
    )
    capability = DeviceCapability.create!(
      device: device,
      key: "history-status",
      name: "History Status",
      capability_type: "status",
      state: { "status" => "available" }
    )

    @tile = @dashboard.dashboard_tiles.create!(title: "Primary", row: 1, column: 1, width: 2, height: 2, position: 1)
    @tile.dashboard_widgets.create!(device_capability: capability, widget_type: "status_badge", title: "Primary Widget", position: 1)
  end

  test "records layout snapshots and undoes the latest change exactly" do
    history = Home::DashboardLayoutHistory.new(dashboard: @dashboard)

    history.record!(label: "Before quick add")
    @dashboard.dashboard_tiles.create!(title: "Secondary", row: 1, column: 3, width: 2, height: 2, position: 2)

    assert_equal 1, history.entries.size
    assert_equal "Before quick add", history.entries.first.fetch("label")

    history.undo!

    assert_equal [ "Primary" ], @dashboard.reload.dashboard_tiles.order(:position).pluck(:title)
    assert_equal [ "Primary Widget" ], @dashboard.dashboard_widgets.pluck(:title)
    assert_empty Home::DashboardLayoutHistory.new(dashboard: @dashboard).entries
  end

  test "keeps only the most recent history entries" do
    history = Home::DashboardLayoutHistory.new(dashboard: @dashboard)

    14.times do |index|
      history.record!(label: "Snapshot #{index}")
    end

    assert_equal Home::DashboardLayoutHistory::MAX_ENTRIES, history.entries.size
    assert_equal "Snapshot 13", history.entries.last.fetch("label")
  end
end
