import { Controller } from "@hotwired/stimulus"

// Manages the slide-over credential panel on the Integrations settings page.
//
// open(event) — reads data-integration-panel-key-param and optionally
//   data-integration-panel-id-param from the triggering button, selects the
//   matching <template>, clones it into the panel body, then slides the panel
//   in from the right.
//
// close() — slides the panel out and clears the body.
//
// The controller also updates the panel header (logo badge + title) from the
// ProviderRegistry metadata embedded in the template's data attributes.

export default class extends Controller {
  static targets = ["panel", "backdrop", "body", "title", "logobadge", "createForm", "updateForm"]

  // Provider metadata baked into the page at render time so we can update
  // the panel header without another round-trip.
  static PROVIDERS = null

  connect() {
    // Build a lookup from the hidden <template> elements present in the DOM.
    this._providerMeta = {}
    this.element.querySelectorAll("template[data-provider-key]").forEach(tpl => {
      const key = tpl.dataset.providerKey
      // Pull the logo badge styles from the provider cards already rendered.
      const card = this.element.querySelector(
        `[data-integration-panel-key-param="${key}"], [data-action*="integration-panel#open"][data-integration-panel-key-param="${key}"]`
      )
      const badge = card?.closest("article")?.querySelector("[style*='background-color']")
      this._providerMeta[key] = {
        template:    tpl,
        bgColor:     badge?.style.backgroundColor || "#6B7280",
        textColor:   badge?.style.color            || "#f9fafb",
        letter:      badge?.textContent?.trim()    || "?",
      }
    })
  }

  open(event) {
    const key           = event.params.key
    const integrationId = event.params.id  // present when reconfiguring

    const meta = this._providerMeta[key]
    if (!meta) return

    // Clone the template content into the panel body.
    const clone = meta.template.content.cloneNode(true)
    this.bodyTarget.innerHTML = ""
    this.bodyTarget.appendChild(clone)

    // Decide whether to show the create or update form.
    const createForm = this.bodyTarget.querySelector("[data-integration-panel-target~='createForm']")
    const updateForm = this.bodyTarget.querySelector("[data-integration-panel-target~='updateForm']")

    if (integrationId) {
      // Update flow — fix the action URL and hide the create form.
      if (updateForm) {
        updateForm.action = updateForm.action.replace("/0", `/${integrationId}`)
        updateForm.style.display = ""
      }
      if (createForm) createForm.style.display = "none"
    } else {
      // Create flow — hide the update form.
      if (updateForm) updateForm.style.display = "none"
      if (createForm) createForm.style.display = ""
    }

    // Update header.
    const name = key.charAt(0).toUpperCase() + key.slice(1)
    this.titleTarget.textContent = integrationId ? `Configure ${name}` : `Connect ${name}`

    const badge = this.logobadgeTarget
    badge.style.backgroundColor = meta.bgColor
    badge.style.color            = meta.textColor
    badge.textContent            = meta.letter

    // Slide in.
    this.backdropTarget.classList.remove("hidden")
    requestAnimationFrame(() => {
      this.panelTarget.classList.remove("translate-x-full")
      this.panelTarget.classList.add("translate-x-0")
    })
  }

  close() {
    this.panelTarget.classList.remove("translate-x-0")
    this.panelTarget.classList.add("translate-x-full")

    // Wait for transition to finish before hiding backdrop + clearing body.
    this.panelTarget.addEventListener("transitionend", () => {
      this.backdropTarget.classList.add("hidden")
      this.bodyTarget.innerHTML = ""
    }, { once: true })
  }

  // Close panel on Escape key.
  closeOnEscape(event) {
    if (event.key === "Escape") this.close()
  }
}
