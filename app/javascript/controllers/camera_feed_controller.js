import { Controller } from "@hotwired/stimulus"

class CameraFeedController extends Controller {
  connect() {
    this.refresh = this.refresh.bind(this)
    this.refresh()
    this.timer = window.setInterval(this.refresh, this.intervalValue)
  }

  disconnect() {
    if (this.timer) {
      window.clearInterval(this.timer)
    }
  }

  loaded() {
    this.imageTarget.classList.remove("hidden")
    this.placeholderTarget.classList.add("hidden")
    this.reportAspect()
  }

  // Publish the feed's true pixel aspect ratio onto the owning dashboard tile so
  // the layout controller can lock camera-tile resizing to the feed's shape.
  reportAspect() {
    const width = this.imageTarget.naturalWidth
    const height = this.imageTarget.naturalHeight
    if (!width || !height) return

    const tile = this.element.closest("[data-dashboard-layout-target='item']")
    if (!tile) return

    tile.dataset.feedAspect = (width / height).toFixed(4)
  }

  failed() {
    this.imageTarget.classList.add("hidden")
    this.placeholderTarget.classList.remove("hidden")
  }

  refresh() {
    if (!this.hasImageTarget || !this.urlValue) {
      return
    }

    const separator = this.urlValue.includes("?") ? "&" : "?"
    this.imageTarget.src = `${this.urlValue}${separator}t=${Date.now()}`
  }
}

CameraFeedController.targets = ["image", "placeholder"]
CameraFeedController.values = {
  interval: { type: Number, default: 4000 },
  url: String,
}

export default CameraFeedController
