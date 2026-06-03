import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["search", "option", "emptyState", "submit"]

  connect() {
    this.filter()
    this.selectionChanged()
  }

  filter() {
    const query = this.searchTarget.value.trim().toLowerCase()
    let visibleCount = 0

    this.optionTargets.forEach((option) => {
      const radio = option.querySelector("input[type='radio']")
      const isSelected = radio ? radio.checked : false
      const visible = query.length === 0 || option.dataset.searchText.includes(query) || isSelected

      option.hidden = !visible
      if (visible) visibleCount += 1
    })

    this.emptyStateTarget.classList.toggle("hidden", visibleCount > 0)
  }

  selectionChanged() {
    const selected = this.element.querySelector("input[type='radio'][name='dashboard_quick_add[device_capability_id]']:checked")
    this.submitTarget.disabled = !selected
  }
}
