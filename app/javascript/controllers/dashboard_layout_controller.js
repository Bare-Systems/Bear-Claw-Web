import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["item"]
  static values = {
    columns: { type: Number, default: 4 },
    maxHeight: { type: Number, default: 3 },
    editingClass: String,
    draggingClass: String,
  }

  connect() {
    this.onPointerMove = this.onPointerMove.bind(this)
    this.onPointerUp = this.onPointerUp.bind(this)
    this.activeInteraction = null
  }

  disconnect() {
    this.teardownInteraction()
  }

  startMove(event) {
    if (event.target.closest("button, a, input, select, textarea, form")) return
    this.beginInteraction(event, "move")
  }

  startResize(event) {
    this.beginInteraction(event, "resize")
  }

  beginInteraction(event, mode) {
    if (event.button !== 0) return

    const tile = event.currentTarget.closest("[data-dashboard-layout-target='item']")
    if (!tile) return

    event.preventDefault()

    const firstTile = this.itemTargets[0]
    const firstHeight = firstTile ? firstTile.getBoundingClientRect().height : 256
    const rowSpan = Number(firstTile?.dataset.height || 1)
    const rowHeight = firstHeight / Math.max(rowSpan, 1)
    const rect = this.element.getBoundingClientRect()
    const cellWidth = rect.width / this.columnsValue

    this.activeInteraction = {
      mode,
      tile,
      tileId: Number(tile.dataset.tileId),
      startX: event.clientX,
      startY: event.clientY,
      startRow: Number(tile.dataset.row),
      startColumn: Number(tile.dataset.column),
      startWidth: Number(tile.dataset.width),
      startHeight: Number(tile.dataset.height),
      committedLayouts: this.captureLayouts(),
      rowHeight,
      cellWidth,
      moved: false,
    }

    tile.classList.add(this.editingClassValue || "ring-2")
    tile.classList.add(this.draggingClassValue || "opacity-80")

    window.addEventListener("pointermove", this.onPointerMove)
    window.addEventListener("pointerup", this.onPointerUp)
  }

  onPointerMove(event) {
    if (!this.activeInteraction) return

    const deltaColumns = Math.round((event.clientX - this.activeInteraction.startX) / this.activeInteraction.cellWidth)
    const deltaRows = Math.round((event.clientY - this.activeInteraction.startY) / this.activeInteraction.rowHeight)
    let preview

    if (this.activeInteraction.mode === "move") {
      const nextColumn = this.clampColumn(this.activeInteraction.startColumn + deltaColumns, this.activeInteraction.startWidth)
      const nextRow = Math.max(this.activeInteraction.startRow + deltaRows, 1)
      preview = { row: nextRow, column: nextColumn, width: this.activeInteraction.startWidth, height: this.activeInteraction.startHeight }
    } else {
      const nextWidth = this.clampWidth(this.activeInteraction.startWidth + deltaColumns, this.activeInteraction.startColumn)
      const nextHeight = this.clampHeight(this.activeInteraction.startHeight + deltaRows)
      preview = { row: this.activeInteraction.startRow, column: this.activeInteraction.startColumn, width: nextWidth, height: nextHeight }
    }

    const layouts = this.normalizeLayouts(this.activeInteraction.committedLayouts, this.activeInteraction.tileId, preview)
    this.previewLayouts(layouts, this.activeInteraction.tileId)
    this.activeInteraction.preview = preview
    this.activeInteraction.moved = true
  }

  onPointerUp() {
    if (!this.activeInteraction) return

    const interaction = this.activeInteraction
    this.teardownInteraction()

    if (!interaction.moved || !interaction.preview) {
      this.restoreTile(interaction.tile)
      return
    }

    this.persistLayout(interaction.tile, interaction.preview)
  }

  async persistLayout(tile, preview) {
    const csrf = document.querySelector("meta[name='csrf-token']")?.content

    try {
      const response = await fetch(tile.dataset.updateUrl, {
        method: "PATCH",
        headers: {
          "Content-Type": "application/json",
          "Accept": "application/json",
          "X-CSRF-Token": csrf,
        },
        body: JSON.stringify({
          dashboard_tile: preview,
        }),
      })

      if (!response.ok) {
        throw new Error(`Tile update failed with status ${response.status}`)
      }

      const payload = await response.json()
      this.commitLayouts(payload.tiles || [])
    } catch (_error) {
      this.restoreCommittedLayout()
      window.location.reload()
    }
  }

  commitLayouts(tiles) {
    tiles.forEach((layout) => {
      const tile = this.itemTargets.find((target) => Number(target.dataset.tileId) === Number(layout.id))
      if (!tile) return

      tile.dataset.row = layout.row
      tile.dataset.column = layout.column
      tile.dataset.width = layout.width
      tile.dataset.height = layout.height
      tile.dataset.position = layout.position
    })

    this.previewLayouts(tiles, null)
    const ordered = [ ...this.itemTargets ].sort((left, right) => Number(left.dataset.position || 0) - Number(right.dataset.position || 0))
    ordered.forEach((tile) => this.element.appendChild(tile))
  }

  previewLayouts(layouts, activeTileId) {
    layouts.forEach((layout) => {
      const tile = this.itemTargets.find((target) => Number(target.dataset.tileId) === Number(layout.id))
      if (!tile) return

      this.renderTileLayout(tile, layout)
      this.applyPreviewState(tile, layout, activeTileId)
    })
  }

  restoreCommittedLayout() {
    this.previewLayouts(this.captureLayouts(), null)
  }

  teardownInteraction() {
    if (this.activeInteraction?.tile) {
      this.activeInteraction.tile.classList.remove(this.editingClassValue || "ring-2")
      this.activeInteraction.tile.classList.remove(this.draggingClassValue || "opacity-80")
      this.activeInteraction.tile.style.zIndex = ""
    }

    window.removeEventListener("pointermove", this.onPointerMove)
    window.removeEventListener("pointerup", this.onPointerUp)
    this.activeInteraction = null
  }

  captureLayouts() {
    return [ ...this.itemTargets ]
      .map((tile) => ({
        id: Number(tile.dataset.tileId),
        row: Number(tile.dataset.row),
        column: Number(tile.dataset.column),
        width: Number(tile.dataset.width),
        height: Number(tile.dataset.height),
        position: Number(tile.dataset.position || 0),
      }))
      .sort((left, right) => {
        if (left.position === right.position) return left.id - right.id
        return left.position - right.position
      })
  }

  normalizeLayouts(layouts, anchorId, anchorPreview) {
    const placements = new Map()
    const occupied = new Set()
    const anchorLayout = layouts.find((layout) => layout.id === anchorId)
    if (!anchorLayout) return layouts

    const anchored = {
      ...anchorLayout,
      ...anchorPreview,
      row: Math.max(anchorPreview.row, 1),
      column: this.clampColumn(anchorPreview.column, anchorPreview.width),
      width: anchorPreview.width,
      height: anchorPreview.height,
    }

    this.place(occupied, anchored.row, anchored.column, anchored.width, anchored.height)
    placements.set(anchorId, { row: anchored.row, column: anchored.column, width: anchored.width, height: anchored.height })

    layouts.forEach((layout) => {
      if (layout.id === anchorId) return

      const placement = this.findFirstFit(occupied, layout.width, layout.height)
      this.place(occupied, placement.row, placement.column, layout.width, layout.height)
      placements.set(layout.id, { row: placement.row, column: placement.column, width: layout.width, height: layout.height })
    })

    return layouts
      .map((layout) => ({ ...layout, ...placements.get(layout.id) }))
      .sort((left, right) => {
        if (left.row === right.row) {
          if (left.column === right.column) return left.id - right.id
          return left.column - right.column
        }
        return left.row - right.row
      })
      .map((layout, index) => ({ ...layout, position: index + 1 }))
  }

  findFirstFit(occupied, width, height) {
    let row = 1

    while (true) {
      const maximumColumn = Math.max(this.columnsValue - width + 1, 1)
      for (let column = 1; column <= maximumColumn; column += 1) {
        if (this.fits(occupied, row, column, width, height)) {
          return { row, column }
        }
      }
      row += 1
    }
  }

  fits(occupied, row, column, width, height) {
    for (let currentRow = row; currentRow < row + height; currentRow += 1) {
      for (let currentColumn = column; currentColumn < column + width; currentColumn += 1) {
        if (occupied.has(`${currentRow}:${currentColumn}`)) return false
      }
    }

    return true
  }

  place(occupied, row, column, width, height) {
    for (let currentRow = row; currentRow < row + height; currentRow += 1) {
      for (let currentColumn = column; currentColumn < column + width; currentColumn += 1) {
        occupied.add(`${currentRow}:${currentColumn}`)
      }
    }
  }

  renderTileLayout(tile, layout) {
    tile.style.gridColumn = `${layout.column} / span ${layout.width}`
    tile.style.gridRow = `${layout.row} / span ${layout.height}`

    const rowLabel = tile.querySelector("[data-dashboard-layout-field='row']")
    const columnLabel = tile.querySelector("[data-dashboard-layout-field='column']")
    const sizeLabel = tile.querySelector("[data-dashboard-layout-field='size']")

    if (rowLabel) rowLabel.textContent = layout.row
    if (columnLabel) columnLabel.textContent = layout.column
    if (sizeLabel) sizeLabel.textContent = `${layout.width}×${layout.height}`
  }

  applyPreviewState(tile, layout, activeTileId) {
    const committed = {
      row: Number(tile.dataset.row),
      column: Number(tile.dataset.column),
      width: Number(tile.dataset.width),
      height: Number(tile.dataset.height),
    }

    const moved = committed.row !== layout.row || committed.column !== layout.column || committed.width !== layout.width || committed.height !== layout.height
    const isActive = Number(tile.dataset.tileId) === Number(activeTileId)

    tile.classList.toggle("border-sky-500/70", moved)
    tile.classList.toggle("shadow-[0_0_0_1px_rgba(56,189,248,0.25)]", moved)
    tile.classList.toggle("bg-sky-950/20", moved && !isActive)
    tile.style.zIndex = isActive ? "20" : ""
  }

  clampColumn(column, width) {
    const maximum = Math.max(this.columnsValue - width + 1, 1)
    return Math.min(Math.max(column, 1), maximum)
  }

  clampWidth(width, startColumn) {
    const maximum = Math.max(this.columnsValue - startColumn + 1, 1)
    return Math.min(Math.max(width, 1), maximum)
  }

  clampHeight(height) {
    return Math.min(Math.max(height, 1), this.maxHeightValue)
  }
}
