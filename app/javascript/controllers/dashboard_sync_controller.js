import { Controller } from "@hotwired/stimulus"
import { cable } from "@hotwired/turbo-rails"

// Connects to DashboardChannel and keeps the dashboard live while the
// tab is open.  On connect it waits for the ActionCable consumer to be
// ready, then:
//
//   1. Subscribes to DashboardChannel.
//   2. Every 30 s sends a "sync" action — the server runs Koala + Polar
//      syncs and broadcasts Turbo Stream fragments back, updating only the
//      changed widgets in-place.
//   3. On disconnect (tab close / navigation) the subscription is torn
//      down, so no syncs fire when nobody is watching.
//
// The first sync is intentionally deferred by 30 s because the page-load
// action already performs a fresh sync before rendering.

class DashboardSyncController extends Controller {
  connect() {
    if (!cable || !cable.subscriptions) {
      this.setStatus("Offline")
      return
    }
    this.subscription = cable.subscriptions.create("DashboardChannel", {
      received: (data) => this.handleMessage(data),
      connected: ()    => this.onConnected(),
      disconnected: () => this.onDisconnected(),
    })
  }

  disconnect() {
    clearInterval(this.timer)
    if (this.subscription) this.subscription.unsubscribe()
    this.subscription = null
  }

  // ── Private ──────────────────────────────────────────────────────────────

  onConnected() {
    // Start the 30 s heartbeat; first tick fires after one interval so
    // the page-load sync isn't immediately duplicated.
    this.timer = setInterval(() => this.requestSync(), this.intervalValue)
    this.setStatus("Connected")
  }

  onDisconnected() {
    clearInterval(this.timer)
    this.setStatus("Reconnecting…")
  }

  requestSync() {
    if (this.subscription) this.subscription.perform("sync")
  }

  handleMessage(data) {
    if (data.turbo_streams) {
      Turbo.renderStreamMessage(data.turbo_streams)
    }
  }

  setStatus(text) {
    if (!this.hasStatusTarget) return
    const colors = {
      "Connected":     "text-emerald-500",
      "Reconnecting…": "text-amber-400",
      "Offline":       "text-gray-600",
    }
    const color = colors[text] || "text-gray-500"
    this.statusTarget.innerHTML = `<span class="text-xs ${color}">${text}</span>`
  }
}

DashboardSyncController.targets = ["status"]
DashboardSyncController.values = { interval: { type: Number, default: 30_000 } }

export default DashboardSyncController
