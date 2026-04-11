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
