import { Controller } from "@hotwired/stimulus"

// Keeps the dashboard grid's row height equal to its column width so that a
// tile's stored width/height units map to a predictable pixel aspect ratio.
//
// The grid is authored as a square-cell grid (the camera-tile height formula and
// the resize math both assume `1 unit wide == 1 unit tall`). But the columns are
// fractional (`repeat(N, minmax(0,1fr))`) so the real column width depends on the
// container, while `grid-auto-rows` was a fixed rem value. At most container
// widths that left rows much taller than columns, so every tile rendered far
// taller than intended and 16:9 camera feeds letterboxed with big black bars.
//
// This controller measures the real column track width and pins `grid-auto-rows`
// to it, on connect and whenever the grid resizes. It runs in both view and edit
// mode so the layout is consistent everywhere.
class SquareGridController extends Controller {
  connect() {
    this.sync = this.sync.bind(this)
    this.observer = new ResizeObserver(this.sync)
    this.observer.observe(this.element)
    // Defer one frame so the grid has been laid out before we measure.
    requestAnimationFrame(this.sync)
  }

  disconnect() {
    if (this.observer) this.observer.disconnect()
  }

  sync() {
    const cell = this.columnWidth()
    if (!cell) return
    const px = `${cell.toFixed(3)}px`
    if (this.element.style.gridAutoRows !== px) {
      this.element.style.gridAutoRows = px
      // Expose the resolved cell size so other controllers (resize math) can
      // read the true row unit instead of guessing from rem.
      this.element.style.setProperty("--dash-cell-px", px)
    }
  }

  // Width of a single column track, derived from the computed template so it is
  // exact regardless of how many columns or how wide the container is.
  columnWidth() {
    const tracks = getComputedStyle(this.element).gridTemplateColumns.split(" ")
    if (!tracks.length) return null
    const first = parseFloat(tracks[0])
    return Number.isFinite(first) && first > 0 ? first : null
  }
}

export default SquareGridController
