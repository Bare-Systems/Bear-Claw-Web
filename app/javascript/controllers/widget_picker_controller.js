import { Controller } from "@hotwired/stimulus"

class WidgetPickerController extends Controller {
  connect() {
    this.element.dataset.widgetPickerReady = "true"
    this.filter()
    this.selectionChanged()
  }

  filter() {
    const query = this.searchTarget.value.trim().toLowerCase()
    const capabilityType = this.capabilityTypeFilterTarget.value
    const provider = this.providerFilterTarget.value

    let visibleCount = 0

    this.optionTargets.forEach((option) => {
      const radio = option.querySelector("input[type='radio']")
      const matchesSearch = query.length === 0 || option.dataset.searchText.includes(query)
      const matchesType = capabilityType.length === 0 || option.dataset.capabilityType === capabilityType
      const matchesProvider = provider.length === 0 || option.dataset.provider === provider
      const isSelected = radio ? radio.checked : false
      const visible = matchesSearch && matchesType && matchesProvider

      option.hidden = !visible && !isSelected
      if (!option.hidden) visibleCount += 1
    })

    this.emptyStateTarget.classList.toggle("hidden", visibleCount > 0)
  }

  selectionChanged() {
    const selected = this.selectedCapability()
    this.updateSelectionSummary(selected)
    this.updateWidgetTypeOptions(selected)
    this.filter()
  }

  selectedCapability() {
    return this.element.querySelector("input[type='radio'][name='dashboard_widget[device_capability_id]']:checked")
  }

  updateSelectionSummary(selected) {
    if (!selected) {
      this.selectedCapabilityNameTarget.textContent = "Choose a capability"
      this.selectedCapabilityContextTarget.textContent = "Provider and device details will appear here."
      this.providerNameTarget.textContent = "—"
      this.capabilityTypeTarget.textContent = "—"
      this.defaultWidgetLabelTarget.textContent = "Choose a capability to load its recommendation."
      this.widgetTypeHintTarget.textContent = "Choose a capability to narrow the valid widget types."
      return
    }

    this.selectedCapabilityNameTarget.textContent = selected.dataset.capabilityName
    this.selectedCapabilityContextTarget.textContent = `${selected.dataset.deviceName} · ${selected.dataset.sourceLabel}`
    this.providerNameTarget.textContent = selected.dataset.providerName
    this.capabilityTypeTarget.textContent = selected.dataset.capabilityTypeLabel
    this.defaultWidgetLabelTarget.textContent = selected.dataset.defaultWidgetLabel

    const allowedWidgetLabels = this.allowedWidgetTypesFor(selected)
      .map((widgetType) => this.widgetTypesValue[widgetType] || this.humanize(widgetType))
      .join(", ")

    this.widgetTypeHintTarget.textContent = `Allowed widget types: ${allowedWidgetLabels}`
  }

  updateWidgetTypeOptions(selected) {
    const currentValue = this.widgetTypeTarget.value
    const previousOptions = Array.from(this.widgetTypeTarget.options).map((option) => ({
      value: option.value,
      text: option.text,
    }))

    this.widgetTypeTarget.innerHTML = ""

    if (!selected) {
      previousOptions.forEach((option) => {
        this.widgetTypeTarget.add(new Option(option.text, option.value))
      })
      return
    }

    this.widgetTypeTarget.add(new Option(`Use capability default (${selected.dataset.defaultWidgetLabel})`, ""))

    this.allowedWidgetTypesFor(selected).forEach((widgetType) => {
      const label = this.widgetTypesValue[widgetType] || this.humanize(widgetType)
      this.widgetTypeTarget.add(new Option(label, widgetType))
    })

    const nextValue = this.allowedWidgetTypesFor(selected).includes(currentValue) ? currentValue : ""
    this.widgetTypeTarget.value = nextValue
  }

  allowedWidgetTypesFor(selected) {
    try {
      return JSON.parse(selected.dataset.allowedWidgetTypes || "[]")
    } catch (_error) {
      return []
    }
  }

  humanize(value) {
    return value.replace(/_/g, " ").replace(/\b\w/g, (match) => match.toUpperCase())
  }
}

WidgetPickerController.targets = [
  "search",
  "capabilityTypeFilter",
  "providerFilter",
  "option",
  "emptyState",
  "selectedCapabilityName",
  "selectedCapabilityContext",
  "providerName",
  "capabilityType",
  "defaultWidgetLabel",
  "widgetType",
  "widgetTypeHint",
]

WidgetPickerController.values = {
  widgetTypes: Object,
}

export default WidgetPickerController
