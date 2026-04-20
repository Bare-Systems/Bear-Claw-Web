import { Controller } from "@hotwired/stimulus"

const TERMINAL_TYPES = ["done", "error"]
const STREAM_TYPES = ["prompt", "tool_call", "tool_result", "model_output", "error", "done"]

class RunStreamController extends Controller {
  connect() {
    this.hasReplayed = false
    if (!this.liveValue || !this.urlValue) return

    this.updateState("Connecting live stream…")
    this.source = new EventSource(this.urlValue)
    STREAM_TYPES.forEach((type) => {
      this.source.addEventListener(type, (event) => this.handleEvent(type, event))
    })
    this.source.onerror = () => {
      if (TERMINAL_TYPES.includes(this.statusTarget.textContent.trim())) return
      this.updateState("Live stream disconnected")
      this.closeSource()
    }
  }

  disconnect() {
    this.closeSource()
  }

  handleEvent(type, event) {
    const payload = JSON.parse(event.data)

    if (this.replayValue && !this.hasReplayed) {
      this.eventsTarget.innerHTML = ""
      this.hasReplayed = true
    }

    this.appendEvent(payload)
    this.updateCount()

    if (TERMINAL_TYPES.includes(type)) {
      this.updateStatus(type)
      this.updateState("Stream complete")
      this.closeSource()
      return
    }

    this.updateStatus("in_progress")
    this.updateState("Live stream connected")
  }

  appendEvent(payload) {
    const item = document.createElement("li")
    item.className = `rounded-2xl border p-4 ${this.eventClasses(payload.type)}`
    item.dataset.runEventType = payload.type || ""
    item.dataset.runEventTs = payload.ts || ""
    item.dataset.runEventTool = payload.tool || ""

    const header = document.createElement("div")
    header.className = "flex items-center justify-between gap-4"

    const titleRow = document.createElement("div")
    titleRow.className = "flex items-center gap-3"

    const badge = document.createElement("span")
    badge.className = "rounded-full border border-white/10 bg-black/20 px-2.5 py-1 text-[11px] font-medium uppercase tracking-[0.18em] text-gray-300"
    badge.textContent = this.eventTitle(payload)
    titleRow.appendChild(badge)

    if (payload.tool) {
      const tool = document.createElement("span")
      tool.className = "text-sm font-medium text-white"
      tool.textContent = payload.tool
      titleRow.appendChild(tool)
    }

    const timestamp = document.createElement("time")
    timestamp.className = "text-xs text-gray-500"
    timestamp.textContent = this.formatTimestamp(payload.ts)

    header.appendChild(titleRow)
    header.appendChild(timestamp)
    item.appendChild(header)

    const fields = [
      ["Tool", payload.tool],
      ["Arguments", payload.arguments],
      ["Content", payload.content],
      ["Message", payload.message],
      ["Code", payload.code],
      ["Success", payload.success === undefined ? null : String(payload.success)]
    ].filter(([, value]) => value !== null && value !== undefined && value !== "")

    if (fields.length > 0) {
      const body = document.createElement("div")
      body.className = "mt-4 space-y-3"

      fields.forEach(([label, value]) => {
        const group = document.createElement("div")
        group.className = "space-y-1"

        const fieldLabel = document.createElement("p")
        fieldLabel.className = "text-[11px] font-medium uppercase tracking-[0.18em] text-gray-500"
        fieldLabel.textContent = label

        const pre = document.createElement("pre")
        pre.className = "overflow-x-auto rounded-xl border border-white/10 bg-black/30 p-3 text-xs leading-6 text-gray-200 whitespace-pre-wrap"
        pre.textContent = value

        group.appendChild(fieldLabel)
        group.appendChild(pre)
        body.appendChild(group)
      })

      item.appendChild(body)
    }

    this.eventsTarget.appendChild(item)
    this.eventsTarget.lastElementChild?.scrollIntoView({ block: "end", behavior: "smooth" })
  }

  updateCount() {
    if (!this.hasCountTarget) return
    this.countTarget.textContent = String(this.eventsTarget.children.length)
  }

  updateStatus(status) {
    if (!this.hasStatusTarget) return
    this.statusTarget.textContent = status
    this.statusTarget.className = `rounded-full px-3 py-1.5 text-xs font-medium ${this.statusClasses(status)}`
  }

  updateState(message) {
    if (this.hasStateTarget) this.stateTarget.textContent = message
  }

  statusClasses(status) {
    switch (status) {
      case "done":
        return "bg-emerald-950 text-emerald-300 border border-emerald-800/60"
      case "error":
        return "bg-red-950 text-red-300 border border-red-800/60"
      default:
        return "bg-sky-950 text-sky-300 border border-sky-800/60"
    }
  }

  eventClasses(type) {
    switch (type) {
      case "prompt":
        return "border-cyan-800/50 bg-cyan-950/20"
      case "tool_call":
        return "border-amber-800/50 bg-amber-950/20"
      case "tool_result":
        return "border-emerald-800/50 bg-emerald-950/20"
      case "model_output":
      case "done":
        return "border-violet-800/50 bg-violet-950/20"
      case "error":
        return "border-red-800/50 bg-red-950/20"
      default:
        return "border-gray-800 bg-gray-950/40"
    }
  }

  eventTitle(payload) {
    switch (payload.type) {
      case "prompt":
        return "Prompt"
      case "tool_call":
        return "Tool Call"
      case "tool_result":
        return "Tool Result"
      case "model_output":
        return "Model Output"
      case "done":
        return "Run Complete"
      case "error":
        return "Error"
      default:
        return (payload.type || "event").replaceAll("_", " ")
    }
  }

  formatTimestamp(unixSeconds) {
    if (!unixSeconds) return "—"
    return new Date(Number(unixSeconds) * 1000).toLocaleString()
  }

  closeSource() {
    if (!this.source) return
    this.source.close()
    this.source = null
  }
}

RunStreamController.targets = ["events", "status", "state", "count", "emptyState"]
RunStreamController.values = {
  live: Boolean,
  replay: Boolean,
  url: String
}

export default RunStreamController
