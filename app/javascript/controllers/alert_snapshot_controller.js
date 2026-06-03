import { Controller } from "@hotwired/stimulus"

class AlertSnapshotController extends Controller {
  failed() {
    this.element.classList.add("hidden")
  }
}

export default AlertSnapshotController
