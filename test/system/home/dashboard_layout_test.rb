require "application_system_test_case"
require "securerandom"

class Home::DashboardLayoutTest < ApplicationSystemTestCase
  setup do
    HouseholdMembership.delete_all
    Household.delete_all

    token = SecureRandom.hex(6)
    @user = User.create!(
      email: "dashboard-layout-#{token}@example.com",
      google_uid: "dashboard-layout-#{token}",
      name: "Dashboard Layout #{token}",
      role: :operator
    )

    household = Household.create!(name: "Layout Test Home #{token}", owner: @user)
    HouseholdMembership.create!(household: household, user: @user)

    dashboard = Dashboard.fetch_or_create_for!(user: @user, context: :home, name: "Home Dashboard")
    dashboard.update!(settings: dashboard.settings_hash.merge("columns" => 8))

    @first_tile = dashboard.dashboard_tiles.create!(
      title: "First Tile",
      row: 1,
      column: 1,
      width: 2,
      height: 2,
      position: 1
    )
    @second_tile = dashboard.dashboard_tiles.create!(
      title: "Second Tile",
      row: 1,
      column: 3,
      width: 2,
      height: 2,
      position: 2
    )
  end

  test "dragging and resizing a tile updates the persisted layout" do
    login_as_test_user
    visit home_root_path(edit: 1)

    assert_selector "[data-controller='dashboard-layout'][data-dashboard-layout-ready='true']"
    assert_selector "#tile-#{@first_tile.id} [data-dashboard-layout-field='size']", text: "2×2"

    move_tile(@first_tile.id, columns: 2, rows: 1)

    assert_selector "#tile-#{@first_tile.id} [data-dashboard-layout-field='row']", text: "2"
    assert_selector "#tile-#{@first_tile.id} [data-dashboard-layout-field='column']", text: "3"

    resize_tile(@first_tile.id, columns: 2, rows: 2)

    assert_selector "#tile-#{@first_tile.id} [data-dashboard-layout-field='size']", text: "4×4"

    visit home_root_path(edit: 1)

    assert_selector "#tile-#{@first_tile.id} [data-dashboard-layout-field='row']", text: "2"
    assert_selector "#tile-#{@first_tile.id} [data-dashboard-layout-field='column']", text: "3"
    assert_selector "#tile-#{@first_tile.id} [data-dashboard-layout-field='size']", text: "4×4"
  end

  private

  def login_as_test_user
    visit "/dev/login?email=#{@user.email}"
  end

  def move_tile(tile_id, columns:, rows:)
    page.execute_script(<<~JS)
      (() => {
        const handle = document.querySelector("#tile-#{tile_id} [data-action*='startMove']")
        const grid = document.querySelector("[data-controller='dashboard-layout']")
        const tile = document.querySelector("#tile-#{tile_id}")
        const firstTile = grid.querySelector("[data-dashboard-layout-target='item']")
        const firstHeight = firstTile ? firstTile.getBoundingClientRect().height : 256
        const rowSpan = Number((firstTile && firstTile.dataset.height) || 1)
        const rowHeight = firstHeight / Math.max(rowSpan, 1)
        const rect = grid.getBoundingClientRect()
        const cellWidth = rect.width / Number(grid.dataset.dashboardLayoutColumnsValue)
        const handleRect = handle.getBoundingClientRect()
        const startX = handleRect.left + 10
        const startY = handleRect.top + 10

        handle.dispatchEvent(new PointerEvent("pointerdown", { bubbles: true, button: 0, clientX: startX, clientY: startY }))
        window.dispatchEvent(new PointerEvent("pointermove", { bubbles: true, clientX: startX + (cellWidth * #{columns}), clientY: startY + (rowHeight * #{rows}) }))
        window.dispatchEvent(new PointerEvent("pointerup", { bubbles: true }))
      })()
    JS
  end

  def resize_tile(tile_id, columns:, rows:)
    page.execute_script(<<~JS)
      (() => {
        const handle = document.querySelector("#tile-#{tile_id} [data-action*='startResize']")
        const grid = document.querySelector("[data-controller='dashboard-layout']")
        const tile = document.querySelector("#tile-#{tile_id}")
        const firstTile = grid.querySelector("[data-dashboard-layout-target='item']")
        const firstHeight = firstTile ? firstTile.getBoundingClientRect().height : 256
        const rowSpan = Number((firstTile && firstTile.dataset.height) || 1)
        const rowHeight = firstHeight / Math.max(rowSpan, 1)
        const rect = grid.getBoundingClientRect()
        const cellWidth = rect.width / Number(grid.dataset.dashboardLayoutColumnsValue)
        const handleRect = handle.getBoundingClientRect()
        const startX = handleRect.left + 8
        const startY = handleRect.top + 8

        handle.dispatchEvent(new PointerEvent("pointerdown", { bubbles: true, button: 0, clientX: startX, clientY: startY }))
        window.dispatchEvent(new PointerEvent("pointermove", { bubbles: true, clientX: startX + (cellWidth * #{columns}), clientY: startY + (rowHeight * #{rows}) }))
        window.dispatchEvent(new PointerEvent("pointerup", { bubbles: true }))
      })()
    JS
  end
end
