require "test_helper"
require "securerandom"

class Home::DashboardLayoutHistoryControllerTest < ActionController::TestCase
  tests Home::DashboardLayoutHistoryController

  setup do
    token = SecureRandom.hex(6)
    @user = User.create!(
      email: "dashboard-history-controller-#{token}@example.com",
      google_uid: "dashboard-history-controller-#{token}",
      name: "Dashboard History Controller #{token}",
      role: :operator
    )
    @request.session[:user_id] = @user.id
    @dashboard = Dashboard.fetch_or_create_for!(user: @user, context: :home, name: "History Dashboard")
    @dashboard.update!(settings: @dashboard.settings_hash.merge("columns" => 8))
    @tile = @dashboard.dashboard_tiles.create!(title: "Alpha", row: 1, column: 1, width: 2, height: 2, position: 1)
  end

  test "undo restores the previous layout snapshot" do
    history = Home::DashboardLayoutHistory.new(dashboard: @dashboard)
    history.record!(label: "Before move")
    @tile.update!(row: 2, column: 5, width: 4, height: 3)

    post :undo, params: { dashboard_id: @dashboard.id }

    assert_redirected_to home_root_path(edit: 1, dashboard: @dashboard.name)
    assert_equal [ 1, 1, 2, 2 ], [ @tile.reload.row, @tile.column, @tile.width, @tile.height ]
  end

  test "undo returns an alert when no history exists" do
    post :undo, params: { dashboard_id: @dashboard.id }

    assert_redirected_to home_root_path(edit: 1, dashboard: @dashboard.name)
    assert_match "No layout history", flash[:alert]
  end
end
