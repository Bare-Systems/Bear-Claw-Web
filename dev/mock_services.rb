#!/usr/bin/env ruby
# dev/mock_services.rb
#
# Local mock servers for Koala, Polar, and Ursa.
# Pure stdlib — no WEBrick. Uses TCPServer from the socket library.
#
# Ports (match the defaults in .env):
#   Koala  → 8082
#   Polar  → 6702
#   Ursa   → 6707
#
# Usage: added to Procfile.dev as `mocks: ruby dev/mock_services.rb`

require "socket"
require "json"
require "base64"
require "securerandom"

# ── HTTP helpers ─────────────────────────────────────────────────────────────

def parse_request(client)
  first = client.gets&.chomp
  return nil if first.nil? || first.empty?

  method, path, _version = first.split(" ", 3)
  headers = {}
  while (line = client.gets&.chomp) && !line.empty?
    k, v = line.split(": ", 2)
    headers[k.downcase] = v if k && v
  end

  body = nil
  if (len = headers["content-length"]&.to_i) && len > 0
    body = client.read(len)
  end

  { method: method, path: path.split("?").first, headers: headers, body: body }
end

def send_response(client, status: 200, content_type: "application/json", body: "")
  body_bytes = body.b
  client.write "HTTP/1.1 #{status} OK\r\n"
  client.write "Content-Type: #{content_type}\r\n"
  client.write "Content-Length: #{body_bytes.bytesize}\r\n"
  client.write "Connection: close\r\n"
  client.write "\r\n"
  client.write body_bytes
rescue Errno::EPIPE, Errno::ECONNRESET
  # client closed early — ignore
ensure
  client.close rescue nil
end

def json_resp(client, data, status: 200)
  send_response(client, status: status, body: JSON.generate(data))
end

def serve(port, name, &handler)
  server = TCPServer.new("127.0.0.1", port)
  puts "[mock] #{name} listening on :#{port}"
  loop do
    client = server.accept
    begin
      req = parse_request(client)
      if req
        handler.call(req, client)
      else
        client.close rescue nil
      end
    rescue => e
      $stderr.puts "[mock] #{name} error: #{e}"
      client.close rescue nil
    end
  end
end

# ── Fixture data ─────────────────────────────────────────────────────────────

NOW = "2026-03-20T22:00:00Z"

CAMERAS = (1..8).map do |n|
  zones = %w[front back side garage driveway yard porch stairs]
  names = ["Front Door", "Back Yard", "Side Gate", "Garage", "Driveway", "Yard", "Front Porch", "Stairs"]
  {
    "id"         => "cam_#{n}",
    "name"       => names[n - 1],
    "status"     => n <= 6 ? "available" : "degraded",
    "zone_id"    => zones[n - 1],
    "capability" => {
      "selected_source" => "snapshot",
      "last_probed_at"  => NOW,
      "last_error"      => n == 7 ? "Probe timeout" : nil
    }.compact
  }
end

POLAR_READINGS = [
  { "station_id" => "home-station", "sensor_id" => "indoor",  "metric" => "co2",        "value" => 412.5, "unit" => "ppm",    "source" => "indoor",  "quality_flag" => "good", "recorded_at" => NOW, "received_at" => NOW },
  { "station_id" => "home-station", "sensor_id" => "indoor",  "metric" => "temperature", "value" => 68.2,  "unit" => "F",      "source" => "indoor",  "quality_flag" => "good", "recorded_at" => NOW, "received_at" => NOW },
  { "station_id" => "home-station", "sensor_id" => "indoor",  "metric" => "humidity",    "value" => 45.1,  "unit" => "%",      "source" => "indoor",  "quality_flag" => "good", "recorded_at" => NOW, "received_at" => NOW },
  { "station_id" => "home-station", "sensor_id" => "indoor",  "metric" => "voc",         "value" => 0.12,  "unit" => "mg/m3",  "source" => "indoor",  "quality_flag" => "good", "recorded_at" => NOW, "received_at" => NOW },
  { "station_id" => "home-station", "sensor_id" => "outdoor", "metric" => "temperature", "value" => 52.1,  "unit" => "F",      "source" => "outdoor", "quality_flag" => "good", "recorded_at" => NOW, "received_at" => NOW },
  { "station_id" => "home-station", "sensor_id" => "outdoor", "metric" => "humidity",    "value" => 61.4,  "unit" => "%",      "source" => "outdoor", "quality_flag" => "good", "recorded_at" => NOW, "received_at" => NOW },
  { "station_id" => "home-station", "sensor_id" => "outdoor", "metric" => "radon",       "value" => 1.2,   "unit" => "pCi/L",  "source" => "outdoor", "quality_flag" => "good", "recorded_at" => NOW, "received_at" => NOW },
]

POLAR_HEALTH = {
  "station_id"   => "home-station",
  "overall"      => "ok",
  "generated_at" => NOW,
  "components"   => [
    { "id" => "indoor",  "status" => "ok", "last_seen" => NOW },
    { "id" => "outdoor", "status" => "ok", "last_seen" => NOW },
    { "id" => "radon",   "status" => "ok", "last_seen" => NOW }
  ]
}

SESSIONS = [
  { "id" => "sess-001", "hostname" => "workstation-01", "os" => "Windows 11",    "status" => "active",
    "campaign" => "internal-assessment", "tags" => ["workstation"],      "last_seen" => NOW, "created_at" => NOW },
  { "id" => "sess-002", "hostname" => "server-02",      "os" => "Ubuntu 22.04",  "status" => "active",
    "campaign" => "internal-assessment", "tags" => ["server", "linux"], "last_seen" => NOW, "created_at" => NOW },
]

MOCK_TASKS = [
  { "id" => "task-001", "session_id" => "sess-001", "task_type" => "shell", "status" => "completed",
    "command" => "whoami", "output" => "CORP\\jdoe", "created_at" => NOW, "completed_at" => NOW },
  { "id" => "task-002", "session_id" => "sess-001", "task_type" => "shell", "status" => "pending",
    "command" => "ipconfig /all", "output" => nil, "created_at" => NOW, "completed_at" => nil },
]

EVENTS = [
  { "id" => "evt-001", "level" => "info",    "message" => "Session registered",          "source" => "implant",   "session_id" => "sess-001", "timestamp" => NOW },
  { "id" => "evt-002", "level" => "warning", "message" => "AV process detected on host", "source" => "detection", "session_id" => "sess-001", "timestamp" => NOW },
  { "id" => "evt-003", "level" => "info",    "message" => "Session registered",          "source" => "implant",   "session_id" => "sess-002", "timestamp" => NOW },
]

CHECKLIST_ITEMS = [
  { "id" => "chk-1", "title" => "Enumerate domain users", "status" => "done", "owner" => "joe", "due_at" => nil, "details" => "Use BloodHound for AD enumeration." },
  { "id" => "chk-2", "title" => "Pivot to server subnet",  "status" => "open", "owner" => "joe", "due_at" => nil, "details" => nil },
  { "id" => "chk-3", "title" => "Capture credentials",     "status" => "open", "owner" => nil,   "due_at" => nil, "details" => nil },
]

CAMPAIGN = {
  "name"             => "internal-assessment",
  "campaign_name"    => "internal-assessment",
  "description"      => "Q1 internal network assessment",
  "status"           => "active",
  "created_at"       => NOW,
  "notes"            => [{ "id" => "note-1", "body" => "Initial foothold via phishing simulation", "note" => "Initial foothold via phishing simulation", "author" => "joe", "created_at" => NOW }],
  "checklist"        => CHECKLIST_ITEMS,
  "checklist_items"  => CHECKLIST_ITEMS,
  "checklist_counts" => { "done" => 1, "open" => 2 },
  "checklist_filters" => {},
  "pending_approvals" => [],
  "alerts"           => [],
  "playbooks"        => [],
  "timeline"         => [
    { "kind" => "event",   "ts" => NOW, "summary" => "Session sess-001 registered", "severity" => "info" },
    { "kind" => "task",    "ts" => NOW, "summary" => "Task task-001 completed (whoami)", "severity" => "info" },
    { "kind" => "event",   "ts" => NOW, "summary" => "AV process detected on host", "severity" => "warning" },
  ],
  "sessions" => SESSIONS,
  "tasks"    => MOCK_TASKS,
  "events"   => EVENTS
}

GOVERNANCE = {
  "approvals" => [
    { "id" => "appr-001", "campaign" => "internal-assessment", "task_type" => "lateral_move",
      "description" => "Pivot to finance VLAN", "risk_level" => "high", "status" => "pending",
      "requested_by" => "joe", "created_at" => NOW }
  ],
  "policies"      => [],
  "policy_alerts" => [],
  "audit_check"   => { "ok" => true, "checked" => 142 }
}

OVERVIEW = {
  "active_count"       => SESSIONS.count { |s| s["status"] == "active" },
  "pending_approvals"  => GOVERNANCE["approvals"].count { |a| a["status"] == "pending" },
  "policy_alert_count" => 0,
  "total_sessions"     => SESSIONS.length,
  "recent_tasks"       => MOCK_TASKS.first(5),
  "recent_events"      => EVENTS.first(5)
}

# Minimal 1x1 gray JPEG placeholder for camera snapshots (verified valid).
PLACEHOLDER_JPEG = Base64.decode64(
  "/9j/4AAQSkZJRgABAQAAAQABAAD/2wBDAAgGBgcGBQgHBwcJCQgKDBQNDAsLDB" \
  "kSEw8UHRofHh0aHBwgJC4nICIsIxwcKDcpLDAxNDQ0Hyc5PTgyPC4zNDL/wAAL" \
  "CAABAAEBAREA/8QAHwAAAQUBAQEBAQEAAAAAAAAAAAECAwQFBgcICQoL/8QAtRAA" \
  "AgEDAwIEAwUFBAQAAAF9AQIDAAQRBRIhMUEGE1FhByJxFDKBkaEII0KxwRVS0f" \
  "AkM2JyggkKFhcYGRolJicoKSo0NTY3ODk6Q0RFRkdISUpTVFVWV1hZWmNkZWZn" \
  "aGlqc3R1dnd4eXqDhIWGh4iJipKTlJWWl5iZmqKjpKWmp6ipqrKztLW2t7i5us" \
  "LDxMXGx8jJytLT1NXW19jZ2uHi4+Tl5ufo6erx8vP09fb3+Pn6/9oACAEBAAA/" \
  "APsooor/2Q=="
).freeze

# ── Koala mock (port 8082) ───────────────────────────────────────────────────

koala_thread = Thread.new do
  serve(8082, "Koala") do |req, client|
    case [req[:method], req[:path]]
    in ["GET", "/healthz"]
      json_resp(client, { status: "ok" })

    in ["POST", "/mcp/tools/koala.list_cameras"]
      json_resp(client, { data: { cameras: CAMERAS } })

    in ["GET", path] if path.match?(%r{\A/admin/cameras/[^/]+/snapshot\z})
      send_response(client, content_type: "image/jpeg", body: PLACEHOLDER_JPEG)

    else
      json_resp(client, { error: "not found" }, status: 404)
    end
  end
end

# ── Polar mock (port 6702) ───────────────────────────────────────────────────

polar_thread = Thread.new do
  serve(6702, "Polar") do |req, client|
    case [req[:method], req[:path]]
    in ["GET", "/healthz"]
      json_resp(client, { status: "ok" })

    in ["GET", "/v1/readings/latest"]
      json_resp(client, POLAR_READINGS)

    in ["GET", "/v1/station/health"]
      json_resp(client, POLAR_HEALTH)

    else
      json_resp(client, { error: "not found" }, status: 404)
    end
  end
end

# ── Ursa mock (port 6707) ────────────────────────────────────────────────────

ursa_thread = Thread.new do
  serve(6707, "Ursa") do |req, client|
    path = req[:path]

    case [req[:method], path]
    in ["GET", "/healthz"]
      json_resp(client, { status: "ok" })

    in ["GET", "/api/v1/overview"]
      json_resp(client, OVERVIEW)

    in ["GET", "/api/v1/sessions"]
      json_resp(client, { sessions: SESSIONS })

    in ["GET", p] if p.match?(%r{\A/api/v1/sessions/[^/]+\z})
      id = path.split("/").last
      session = SESSIONS.find { |s| s["id"] == id } || SESSIONS.first
      json_resp(client, {
        session: session,
        tasks:   MOCK_TASKS.select { |t| t["session_id"] == session["id"] },
        files:   [],
        events:  EVENTS.select { |e| e["session_id"] == session["id"] }
      })

    in ["GET", "/api/v1/tasks"]
      json_resp(client, { tasks: MOCK_TASKS })

    in ["GET", p] if p.match?(%r{\A/api/v1/tasks/[^/]+\z})
      id = path.split("/").last
      task = MOCK_TASKS.find { |t| t["id"] == id } || MOCK_TASKS.first
      json_resp(client, { task: task })

    in ["GET", "/api/v1/events"]
      json_resp(client, { events: EVENTS })

    in ["GET", "/api/v1/campaigns"]
      json_resp(client, { campaigns: [CAMPAIGN] })

    in ["GET", "/api/v1/campaigns/playbooks"]
      json_resp(client, { playbooks: [] })

    in ["GET", p] if p.match?(%r{\A/api/v1/campaigns/[^/]+/handoff\z})
      json_resp(client, CAMPAIGN)

    in ["GET", p] if p.match?(%r{\A/api/v1/campaigns/[^/]+\z})
      json_resp(client, CAMPAIGN)

    in ["GET", "/api/v1/governance"]
      json_resp(client, GOVERNANCE)

    in ["GET", "/api/v1/governance/report"]
      json_resp(client, { report: GOVERNANCE })

    in ["GET", "/api/v1/files"]
      json_resp(client, { files: [] })

    in ["GET", "/api/v1/users"]
      json_resp(client, { users: [] })

    else
      # Catch-all for POST/PATCH/DELETE mutations - just ack
      json_resp(client, { ok: true })
    end
  end
end

# ── BearClaw mock (port 8080) ─────────────────────────────────────────────────
#
# Contract:
#   GET  /health            → { status: "ok" }
#   POST /v1/chat           → { message: { id:, content: } }
#   GET  /v1/cron           → { jobs: [...] }
#   POST /v1/cron           → { job: {...} }
#   PATCH /v1/cron/:id      → { job: {...} }
#   DELETE /v1/cron/:id     → { ok: true }
#   GET  /v1/memory         → { entries: [...] }
#   DELETE /v1/memory/:id   → { ok: true }

CRON_JOBS = [
  { "id" => "cron-001", "name" => "Health check",        "schedule" => "*/5 * * * *",  "command" => "health_check",   "args" => {}, "enabled" => true,  "last_run_at" => NOW, "last_status" => "ok",    "next_run_at" => NOW },
  { "id" => "cron-002", "name" => "Docker stack report", "schedule" => "0 8 * * *",    "command" => "docker_report",  "args" => {}, "enabled" => true,  "last_run_at" => NOW, "last_status" => "ok",    "next_run_at" => NOW },
  { "id" => "cron-003", "name" => "Disk usage alert",    "schedule" => "0 */6 * * *",  "command" => "disk_check",     "args" => {}, "enabled" => false, "last_run_at" => NOW, "last_status" => "error", "next_run_at" => nil  },
]

MEMORY_ENTRIES = [
  { "id" => "mem-001", "type" => "user",      "name" => "user_role",          "description" => "Primary homelab operator",          "content" => "Joe is the primary homelab operator and admin. He uses BearClaw to manage the Bare Systems stack on blink.",        "created_at" => NOW },
  { "id" => "mem-002", "type" => "project",   "name" => "bearclaw_vision",    "description" => "BearClaw is the AI DevOps agent",    "content" => "BearClaw is built to be Joe's on-call DevOps agent — SSH into blink, inspect containers, restart services.",        "created_at" => NOW },
  { "id" => "mem-003", "type" => "feedback",  "name" => "terse_responses",    "description" => "Keep responses concise",             "content" => "Joe prefers terse, direct responses. Skip preamble and filler. Lead with the answer.",                              "created_at" => NOW },
  { "id" => "mem-004", "type" => "reference", "name" => "proxmox_url",        "description" => "Proxmox management UI",              "content" => "Proxmox web UI at https://blink:8006. Docker stack managed via Portainer through Tardigrade reverse proxy.",         "created_at" => NOW },
]

bearclaw_thread = Thread.new do
  serve(8080, "BearClaw") do |req, client|
    path = req[:path]

    case [req[:method], path]
    in ["GET", "/health"] | ["GET", "/healthz"]
      json_resp(client, { status: "ok" })

    in ["POST", "/v1/chat"]
      body = JSON.parse(req[:body].to_s) rescue {}
      msg  = body["message"].to_s
      json_resp(client, {
        "message" => {
          "id"      => "bc-#{SecureRandom.hex(4)}",
          "content" => "Mock BearClaw response to: \"#{msg[0, 80]}#{msg.length > 80 ? "…" : ""}\". (This is the mock agent — connect BEARCLAW_URL to a real instance for live responses.)"
        }
      })

    in ["GET", "/v1/cron"]
      json_resp(client, { "jobs" => CRON_JOBS })

    in ["POST", "/v1/cron"]
      body = JSON.parse(req[:body].to_s) rescue {}
      new_job = body.merge("id" => "cron-#{SecureRandom.hex(4)}", "last_run_at" => nil, "last_status" => nil, "next_run_at" => nil)
      json_resp(client, { "job" => new_job }, status: 201)

    in ["PATCH", p] if p.match?(%r{\A/v1/cron/[^/]+\z})
      id   = path.split("/").last
      job  = CRON_JOBS.find { |j| j["id"] == id } || { "id" => id }
      body = JSON.parse(req[:body].to_s) rescue {}
      json_resp(client, { "job" => job.merge(body) })

    in ["DELETE", p] if p.match?(%r{\A/v1/cron/[^/]+\z})
      json_resp(client, { "ok" => true })

    in ["GET", "/v1/memory"]
      json_resp(client, { "entries" => MEMORY_ENTRIES })

    in ["DELETE", p] if p.match?(%r{\A/v1/memory/[^/]+\z})
      json_resp(client, { "ok" => true })

    else
      json_resp(client, { "error" => "not found" }, status: 404)
    end
  end
end

# ── Run ───────────────────────────────────────────────────────────────────────

[bearclaw_thread, koala_thread, polar_thread, ursa_thread].each(&:join)
