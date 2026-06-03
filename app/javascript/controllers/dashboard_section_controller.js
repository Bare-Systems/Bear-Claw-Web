import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["details", "buttonLabel"]
  static values = {
    expanded: { type: Boolean, default: true },
    storageKey: String,
  }

  connect() {
    this.expandedValue = this.loadExpandedState()
    this.render()
  }

  toggle() {
    this.expandedValue = this.hasDetailsTarget ? this.detailsTarget.open : !this.expandedValue
    this.persistExpandedState()
    this.render()
  }

  loadExpandedState() {
    if (!this.hasStorageKeyValue) return this.expandedValue

    try {
      const stored = window.localStorage.getItem(this.storageKeyValue)
      return stored == null ? this.expandedValue : stored === "true"
    } catch (_error) {
      return this.expandedValue
    }
  }

  persistExpandedState() {
    if (!this.hasStorageKeyValue) return

    try {
      window.localStorage.setItem(this.storageKeyValue, String(this.expandedValue))
    } catch (_error) {
      // Ignore storage failures so dashboard rendering still works in locked-down browsers.
    }
  }

  render() {
    if (this.hasDetailsTarget && this.detailsTarget.open !== this.expandedValue) {
      this.detailsTarget.open = this.expandedValue
    }

    if (this.hasButtonLabelTarget) {
      this.buttonLabelTarget.textContent = this.expandedValue ? "Collapse" : "Expand"
    }
  }
}
