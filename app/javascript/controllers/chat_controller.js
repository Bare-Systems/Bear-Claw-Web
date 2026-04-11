import { Controller } from "@hotwired/stimulus"

class ChatController extends Controller {
  connect() {
    this.expanded = this.expandedValue
    this.syncExpandedState()
    this.scrollToBottom()
    this.autoResize({ target: this.inputTarget })
  }

  // ── Input ──────────────────────────────────────────────────────────────────

  handleKeydown(event) {
    if (event.key === "Enter" && !event.shiftKey) {
      event.preventDefault()
      this.formTarget.requestSubmit()
    }
  }

  autoResize(event) {
    const el = event.target || event
    el.style.height = "auto"
    el.style.height = `${Math.min(el.scrollHeight, 160)}px`
  }

  // ── Form lifecycle ─────────────────────────────────────────────────────────

  onSubmit(event) {
    if (!this.inputTarget.value.trim()) {
      event.preventDefault()
      return
    }
    this.open()
    this.setLoading(true)
  }

  onSubmitEnd(event) {
    this.setLoading(false)
    if (event.detail && event.detail.success === false) {
      this.focusInput()
      return
    }

    this.inputTarget.value = ""
    this.autoResize({ target: this.inputTarget })
    this.focusInput()
    requestAnimationFrame(() => requestAnimationFrame(() => this.scrollToBottom()))
  }

  // ── Actions ────────────────────────────────────────────────────────────────

  toggle() {
    if (this.expanded) {
      this.close()
      return
    }

    this.open()
  }

  open() {
    this.expanded = true
    this.syncExpandedState()
    this.focusInput()
    requestAnimationFrame(() => this.scrollToBottom())
  }

  close() {
    this.expanded = false
    this.syncExpandedState()
    if (this.hasLauncherTarget) this.launcherTarget.focus()
  }

  clear() {
    Array.from(this.messagesTarget.children).forEach((el) => {
      if (el.id !== "chat-empty") el.remove()
    })

    if (!this.hasEmptyTarget) {
      this.messagesTarget.appendChild(this.buildEmptyState())
    }

    this.scrollToBottom()
    this.focusInput()
  }

  handleWindowKeydown(event) {
    if (event.key === "Escape" && this.expanded && this.hasLauncherTarget) {
      this.close()
    }
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  setLoading(active) {
    // Don't disable the textarea — Turbo serializes FormData from the submit event
    // on the form element, which fires before this handler runs. Disabling the input
    // here would cause the message param to be missing from the request.
    this.submitTarget.disabled = active
    this.loadingTarget.classList.toggle("hidden", !active)
    this.loadingTarget.classList.toggle("flex",    active)
  }

  scrollToBottom() {
    this.messagesTarget.scrollTop = this.messagesTarget.scrollHeight
  }

  syncExpandedState() {
    if (!this.hasPanelTarget) return

    if (this.hasLauncherTarget) {
      this.launcherTarget.classList.toggle("hidden", this.expanded)
      this.launcherTarget.setAttribute("aria-expanded", this.expanded ? "true" : "false")
    }

    this.panelTarget.classList.toggle("pointer-events-none", !this.expanded)
    this.panelTarget.classList.toggle("opacity-0", !this.expanded)
    this.panelTarget.classList.toggle("translate-y-3", !this.expanded)
    this.panelTarget.classList.toggle("scale-[0.98]", !this.expanded)
    this.panelTarget.classList.toggle("hidden", !this.expanded && this.hasLauncherTarget)
    this.panelTarget.classList.toggle("transition-all", this.hasLauncherTarget)
    this.panelTarget.classList.toggle("duration-200", this.hasLauncherTarget)
    this.panelTarget.classList.toggle("ease-out", this.hasLauncherTarget)
  }

  focusInput() {
    requestAnimationFrame(() => this.inputTarget.focus())
  }

  buildEmptyState() {
    const empty = document.createElement("div")
    empty.id = "chat-empty"
    empty.dataset.chatTarget = "empty"
    empty.className = "flex h-full flex-col items-center justify-center gap-4 text-center"
    empty.innerHTML = `
      <span class="flex h-14 w-14 items-center justify-center rounded-[1.25rem] border border-emerald-400/20 bg-emerald-400/10 text-xs font-semibold tracking-[0.3em] text-emerald-200">BC</span>
      <div class="space-y-1">
        <p class="text-sm font-medium text-gray-200">Start a conversation</p>
        <p class="max-w-xs text-xs leading-5 text-gray-500">Ask BearClaw to inspect services, explain alerts, or plan homelab work.</p>
      </div>
    `
    return empty
  }
}

ChatController.targets = ["launcher", "panel", "messages", "input", "submit", "loading", "form", "empty"]
ChatController.values = { expanded: Boolean }

export default ChatController
