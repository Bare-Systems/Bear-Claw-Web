require "test_helper"

class Home::DashboardTilesControllerTest < ActionController::TestCase
  tests Home::DashboardTilesController

  setup do
    @user = User.find_by!(email: users(:one)["email"])
    @user.update!(role: :operator)
    @request.session[:user_id] = @user.id
    @dashboard = Dashboard.fetch_or_create_for!(user: @user, context: :home, name: "Home Dashboard")
  end

  test "creates a custom tile" do
    assert_difference("DashboardTile.count", 1) do
      post :create, params: {
        dashboard_tile: {
          title: "Climate",
          row: 3,
          column: 1,
          width: 2,
          height: 1
        }
      }
    end

    tile = DashboardTile.order(:id).last

    assert_redirected_to home_root_path(edit: 1)
    assert_equal "Climate", tile.title
    assert_equal 2, tile.width
  end

  test "updates tile layout over json and returns normalized positions" do
    first = @dashboard.dashboard_tiles.create!(title: "First", row: 1, column: 1, width: 1, height: 1, position: 1)
    second = @dashboard.dashboard_tiles.create!(title: "Second", row: 1, column: 2, width: 1, height: 1, position: 2)

    patch :update, params: {
      id: first.id,
      dashboard_tile: {
        row: 1,
        column: 2,
        width: 1,
        height: 1
      },
      format: :json
    }

    assert_response :success

    payload = JSON.parse(@response.body)
    updated_first = payload.fetch("tiles").find { |tile| tile.fetch("id") == first.id }
    updated_second = payload.fetch("tiles").find { |tile| tile.fetch("id") == second.id }

    assert_equal 2, updated_first.fetch("column")
    assert_equal 1, updated_second.fetch("column")
  end
end
