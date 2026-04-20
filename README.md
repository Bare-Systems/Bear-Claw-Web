# BearClawWeb

Rails 8 application for Bare Systems operator workflows.

BearClawWeb is the only human-facing web UI. It renders the operator experience
for:
- BearClaw agent workflows
- Koala home workflows
- Ursa security workflows

Agent requests to BearClaw should go through Tardigrade, not directly to the
loopback BearClaw port. Configure `BEARCLAW_URL` with the edge mount path, for
example `https://bearclaw.baresystems.com/bearclaw`, so BearClawWeb can send
scoped Tardigrade JWTs and let the edge assert `X-Tardigrade-User-ID`,
`X-Tardigrade-Device-ID`, and `X-Tardigrade-Scopes` upstream.

The agent module also includes a Runs viewer at `/agent/runs`. That page reads
BearClaw run-artifact APIs through the Rails backend, then proxies live SSE to
the browser so operator sessions can inspect tool-call traces without exposing
BearClaw auth headers to client-side JavaScript.

The agent module also includes a transcript viewer at `/agent/transcripts`.
That page reads Tardigrade's redacted `/bearclaw/transcripts` APIs through the
Rails backend so operator sessions can inspect edge request/response captures
without giving the browser direct access to transcript storage.

## Homelab Network Contract

The working `blink` topology is:

- Public TLS entrypoint: Tardigrade on `https://bearclaw.baresystems.com`
- Tardigrade upstream for BearClaw: `http://127.0.0.1:6701`
- BearClaw container host: `192.168.86.53`
- Koala API for Home pages: `http://192.168.86.53:8082`
- Polar API for Home climate pages: `http://192.168.86.53:6703`
- Ursa control plane for Security pages: `http://192.168.86.53:6707`

Do not change those boundaries casually:

- BearClaw itself stays loopback-only on the host. Do not expose `6701` on the
  LAN to make the site work.
- BearClaw runs in Docker, so host services must be reached through the host IP.
  Do not use `127.0.0.1` inside the BearClaw container for Koala or Ursa.
- Koala is the special case on `blink`: the camera-facing orchestrator has to
  run on host networking because Docker bridge containers could not reach the
  DVR on `192.168.86.46` during the March 20, 2026 outage.

## Service Boundaries

- `BearClawWeb` is the UI layer.
- `Ursa major/server.py` is the C2 runtime for implants.
- `Ursa major.web` is the BearClaw-facing control-plane service over the Ursa
  datastore. It serves both REST and MCP on the same published port.
- `Koala` is the Home-camera API and snapshot service.
- `Polar` is the Home climate and environmental telemetry API.

BearClawWeb does not talk directly to the Ursa C2 listener for Security pages.
It depends on the bearer-authenticated control-plane API exposed by `major.web`
under `/api/v1/*`. Agent clients can use the same service under `/mcp`.

## Configuration

Required env vars for the Security module:
- `URSA_URL`
- `URSA_TOKEN`

`URSA_TOKEN` must match `major.web.auth.api_token` in Ursa.

When BearClawWeb runs in Docker on the homelab host, `URSA_URL` must point at
the host-published Ursa control-plane address, not the host loopback device from
inside the container. The current homelab deployment expects:

```env
URSA_URL=http://192.168.86.53:6707
```

Home pages follow the same rule for Koala:

```env
KOALA_URL=http://192.168.86.53:8082
```

Polar-backed Home climate widgets follow the same rule:

```env
POLAR_URL=http://192.168.86.53:6703
POLAR_TOKEN=<polar service token>
```

BearClaw agent requests also need the shared Tardigrade JWT settings:

```env
TARDIGRADE_JWT_SECRET=<shared hs256 secret>
TARDIGRADE_JWT_ISSUER=bearclaw-web
TARDIGRADE_JWT_AUDIENCE=bearclaw-api
```

## Failure Behavior

If Ursa is unavailable, Security pages should render a stable unavailable page.
They must not redirect back to `/security` in a loop.

If Koala is unavailable, the Home dashboard should degrade to unavailable camera
tiles. It should not assume cameras are down until host-to-Koala reachability
has been checked.

If BearClaw is unavailable, `/agent/runs` and `/agent/runs/:id` should render a
stable unavailable state rather than raising or redirect-looping. Rendered run
artifacts must only contain the redacted payloads returned by BearClaw; raw
bearer tokens should never appear in the HTML response.

## Deployment Validation

The homelab Blink deploy for BearClaw is image-based:

- Blink builds the production Docker image locally on the Mac host.
- The local build runs inside a Docker builder container with the repo
  bind-mounted into `/workspace`.
- Blink uploads the saved image tarball artifact to `blink`.
- The remote host only does `docker load` + `docker run`.
- The remote host must not unpack the repo or run `docker build` for BearClaw.

After a deploy on `blink`, the minimum network checks are:

```bash
curl -sS http://192.168.86.53:8082/healthz
curl -sS http://192.168.86.53:6707/healthz
docker exec bearclaw-web ruby -rnet/http -e 'print Net::HTTP.get_response(URI("http://192.168.86.53:8082/healthz")).code'
docker exec bearclaw-web ruby -rnet/http -e 'print Net::HTTP.get_response(URI("http://192.168.86.53:6707/healthz")).code'
docker exec bearclaw-web ruby -rsocket -e 'Socket.getaddrinfo("oauth2.googleapis.com", 443); print "ok"'
```

## Tests

The test environment uses SQLite so request/controller tests do not depend on a
local Postgres instance.

Run the focused regression tests with:

```bash
bundle exec rails test test/controllers/agent/runs_controller_test.rb test/controllers/agent/transcripts_controller_test.rb test/services/bearclaw_client_test.rb test/integration/agent_runs_flow_test.rb test/integration/agent_transcripts_flow_test.rb
```
