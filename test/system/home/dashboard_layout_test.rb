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
    dashboard.update!(settings: dashboard.settings_hash.merge("columns" => 80, "density_version" => 3))
    base_span = dashboard.default_tile_span

    @first_tile = dashboard.dashboard_tiles.create!(
      title: "First Tile",
      row: 1,
      column: 1,
      width: base_span,
      height: base_span,
      position: 1
    )
    @second_tile = dashboard.dashboard_tiles.create!(
      title: "Second Tile",
      row: 1,
      column: base_span + 1,
      width: base_span,
      height: base_span,
      position: 2
    )
  end

  test "dragging and resizing a tile updates the persisted layout" do
    login_as_test_user
    visit home_root_path(edit: 1)

    assert_selector "[data-controller~='dashboard-layout'][data-dashboard-layout-ready='true']"
    assert_selector "#tile-#{@first_tile.id} [data-dashboard-layout-field='size']", text: "20×20"

    move_tile(@first_tile.id, columns: 10, rows: 5)

    assert_selector "#tile-#{@first_tile.id} [data-dashboard-layout-field='row']", text: "6"
    assert_selector "#tile-#{@first_tile.id} [data-dashboard-layout-field='column']", text: "11"
    # Wait for the move PATCH to commit before starting the resize.
    # renderTileLayout updates labels immediately (JS preview) but data-row/data-column
    # are only set by commitLayouts once the server responds. If the resize reads stale
    # data attributes it will anchor from row=1/col=1, overwriting the move in the DB.
    assert_selector "#tile-#{@first_tile.id}[data-row='6'][data-column='11']"

    resize_tile(@first_tile.id, columns: 12, rows: 10)

    assert_selector "#tile-#{@first_tile.id} [data-dashboard-layout-field='size']", text: "32×30"
    # Wait for the resize PATCH to commit before navigating away, so the DB reflects
    # the final size before the page reloads.
    assert_selector "#tile-#{@first_tile.id}[data-width='32'][data-height='30']"

    visit home_root_path(edit: 1)

    assert_selector "#tile-#{@first_tile.id} [data-dashboard-layout-field='row']", text: "6"
    assert_selector "#tile-#{@first_tile.id} [data-dashboard-layout-field='column']", text: "11"
    assert_selector "#tile-#{@first_tile.id} [data-dashboard-layout-field='size']", text: "32×30"
  end

  test "resize handle can widen or heighten a tile independently" do
    login_as_test_user
    visit home_root_path(edit: 1)

    assert_selector "#tile-#{@first_tile.id} [data-dashboard-layout-field='size']", text: "20×20"

    resize_tile(@first_tile.id, columns: 10, rows: 0)
    assert_selector "#tile-#{@first_tile.id} [data-dashboard-layout-field='size']", text: "30×20"

    visit home_root_path(edit: 1)
    assert_selector "#tile-#{@first_tile.id} [data-dashboard-layout-field='size']", text: "30×20"

    resize_tile(@first_tile.id, columns: 0, rows: 5)
    assert_selector "#tile-#{@first_tile.id} [data-dashboard-layout-field='size']", text: "30×25"
  end

  private

  def login_as_test_user
    visit "/dev/login?email=#{@user.email}"
  end

  def move_tile(tile_id, columns:, rows:)
    page.execute_script(<<~JS)
      (() => {
        const handle = document.querySelector("#tile-#{tile_id} [data-action*='startMove']")
        const grid = document.querySelector("[data-controller~='dashboard-layout']")
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
        const grid = document.querySelector("[data-controller~='dashboard-layout']")
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
