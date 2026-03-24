# BearClaw Web — Ad Hoc Test Plan

Last updated: 2026-03-21
Environment: local dev (`bin/dev`) with mock services (Koala :8082, Polar :6702, Ursa :18080)

---

## How to use this file

Work through each section top-to-bottom. Mark each item `[x]` when it passes, `[!]` when it fails (add a note inline). After a feature changes, re-run its section and reset marks.

---

## 0. Pre-flight

- [x] `bin/dev` starts without error (web + css + mocks all running)
- [x] `/up` returns 200
- [x] Mock Koala responds: `curl http://localhost:8082/healthz` → `{"status":"ok"}`
- [x] Mock Polar responds: `curl http://localhost:6702/healthz` → `{"status":"ok"}`
- [x] Mock Ursa responds: `curl http://localhost:18080/healthz` → `{"status":"ok"}`

---

## 1. Auth

- [x] `/login` renders the login page
- [x] Dev login button (`/dev/login`) signs in as `admin` user and redirects to Agent root
- [x] Signed-in user sees nav (Agent, Home, Security, Admin)
- [x] Sign out → redirected to login, nav hidden

---

## 2. Home Dashboard

### 2a. Page load

- [x] Navigate to `/home` — page loads, "HOME OPS" label visible
- [x] Edit / Cameras / Zones buttons visible top-right
- [x] Sync status shows "Offline" (or "Connected" if ActionCable is live) — subtle gray text, not prominent
- [x] No page errors in browser console

### 2b. Tile grid — view mode

- [x] All tiles render in a 4-column grid (scrollable horizontally if viewport < 48rem)
- [x] Camera tiles: image fills full tile body, minimal name label at bottom, no status badge, no footer
- [x] Sensor tiles (Temperature, Humidity, CO₂, VOC, Radon): values visible, units correct
- [x] CAM 7 shows "Degraded" status in hover overlay (not green)
- [x] Hovering a camera tile shows the overlay: widget name + status badge + camera ID + timestamp
- [x] Timestamps format as `YYYY-MM-DD HH:MM:SS` (not raw ISO string or "56 years ago")

### 2c. Edit mode

- [x] Click "Edit" → URL gains `?edit=1`, editor sidebar appears
- [x] Each tile header shows: position meta (Row/Col/Size/widget count), "DRAG HEADER" + "EDITABLE" badges
- [x] Edit hint text visible below "HOME OPS" row: "Drag a tile header to move · resize corner to resize"
- [x] Click "Done Editing" → edit mode exits, editor sidebar gone, badges gone

### 2d. Drag to move

- [x] In edit mode: grab a tile header, drag it to a new column position → tile moves
- [x] After drop, tile's meta line updates to new Row/Column
- [x] Reload page → tile is still at new position (PATCH persisted)

### 2e. Resize

- [x] In edit mode: click "resize corner" on a tile and drag right → tile expands to 2 columns
- [x] Tile meta updates: Size shows 2×1
- [x] Reload → tile still 2 columns wide

### 2f. Tile CRUD (editor sidebar)

- [x] Create tile: fill in title, row, column, width, height → "Create Tile" → "Tile added." flash, tile appears in grid
- [x] Save tile: change title in editor, "Save Tile" → title updates
- [x] Delete tile: click "Delete" → confirm dialog shows tile name ("Delete 'X' and all its widgets?") → confirm → "Tile removed." flash, tile gone

### 2g. Widget CRUD

- [x] Add widget: pick capability + widget type → "Add Widget" → "Widget added." flash, widget appears in tile
- [x] Empty tile shows dashed "Empty Tile" placeholder in view mode
- [x] Remove widget: click "Remove" → confirm dialog ("Remove this Camera Feed widget?") → "Widget removed." flash
- [x] Save widget: change title in editor, "Save Widget" → title updates in tile header

### 2h. Service config (editor sidebar)

- [x] Provider create form renders; submitting creates a new provider entry
- [x] Connection create form renders; provider dropdown populated
- [x] Device create form renders; connection dropdown populated
- [x] Capability appears in the "Add Widget" capability dropdown after creation

---

## 3. Cameras page

- [x] `/home/cameras` loads, shows camera wall
- [x] Each camera tile renders with snapshot image (or no-signal state)
- [x] Camera status badge (Available / Degraded) shows correctly
- [x] Timestamp formats as `YYYY-MM-DD HH:MM:SS` (fixed 2026-03-21: was showing raw ISO string)

---

## 4. Agent module

### 4a. Chat

- [x] `/agent` loads Agent dashboard
- [x] BearClaw chat widget visible bottom-right (floating pill)
- [x] Click pill → chat panel opens at `/agent/chat`
- [x] Send a message → response appears (streamed or full)
- [x] Chat history persists within session

### 4b. Cron

- [x] `/agent/cron` lists scheduled tasks (empty or seeded)
- [ ] Create a cron job → appears in list
- [ ] Update a cron job → changes saved
- [ ] Delete a cron job → removed

### 4c. Memory

- [x] `/agent/memory` lists memory entries
- [ ] Delete a memory entry → removed

---

## 5. Security module

### 5a. Dashboard

- [x] `/security` loads, shows overview stats from Ursa mock
- [x] Active sessions count: 2, Pending approvals: 1

### 5b. Sessions

- [x] `/security/sessions` lists sess-001 and sess-002
- [x] Click a session → detail page shows hostname, OS, tasks, events
- [x] "Queue Task" button present on session detail

### 5c. Tasks

- [x] `/security/tasks` lists task-001 (completed) and task-002 (pending)
- [x] Click a task → detail page shows command, output, status

### 5d. Campaigns

- [x] `/security/campaigns` shows "internal-assessment" campaign (fixed 2026-03-21: UrlGenerationError — mock returned array of objects, view expected hash)
- [x] Campaign detail shows notes, checklist items, sessions, tasks, events
- [x] Add note → "Campaign note added." flash
- [x] Toggle checklist item (done ↔ open) → "Checklist item updated." flash

### 5e. Governance

- [x] `/security/governance` loads, shows pending approval appr-001 (high risk, internal-assessment)
- [x] Approve / Reject buttons present
- [x] Audit check shows ✓ ok, 142 checked

### 5f. Events

- [x] `/security/events` lists 3 mock events
- [x] Info and warning levels styled differently (info: plain, warning: amber pill)

---

## 6. Settings module

- [x] `/settings` loads integration list (Govee, Airthings, Custom)
- [x] Create integration form renders (slide-over panel with API Key field)
- [ ] Create → integration appears in list (requires real backend persist; not tested with mock)
- [ ] Update → changes save
- [ ] Delete → removed (with confirm if applicable)

---

## 7. Admin module

- [x] `/admin` loads admin dashboard (Users, Settings, Audit Log links)
- [x] `/admin/users` lists users (Dev Admin + Joe Caruso), edit link present
- [x] `/admin/settings` loads (stub: "coming soon")
- [x] `/admin/audit` loads (stub: "coming soon")

---

## 8. Cross-cutting

- [x] Flash messages (success/error) appear and auto-dismiss or are dismissible
- [x] No unhandled 500 errors on any page listed above (campaigns index fixed)
- [x] Nav active state highlights correct module on each page
- [x] BearClaw chat widget is hidden on the `/agent/chat` page itself (not double-rendered)
- [x] Sign-out works from every module

---

## Known limitations / not yet tested

- ActionCable live sync (DashboardChannel) — requires real WebSocket, not available in preview
- OAuth login (GitHub/Google) — only dev login tested locally
- Real Koala/Polar/Ursa endpoints — all tests above use mock services
- Mobile layout — horizontal scroll works but not tested on actual device
- Agent cron CRUD (create/update/delete) — stub pages load but mutations not tested
- Settings integrations persist — slide-over form renders but create/update/delete not tested end-to-end against mock

## Bugs fixed during this run (2026-03-21)

- **Camera wall timestamp** — `_camera_wall.html.erb` showed raw ISO string; fixed with `ursa_timestamp()`
- **Campaigns index crash** — `UrlGenerationError` because mock returned `[CAMPAIGN]` array but view iterated as `|name, counts|` hash; fixed view to iterate array of objects
- **Campaign show crash** — view used `"campaign_name"`, `"checklist_items"`, `"pending_approvals"`, `"timeline"` keys not present in mock; enriched CAMPAIGN mock with all required fields
