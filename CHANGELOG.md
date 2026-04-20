# Changelog

All notable changes to BearClawWeb are documented here.

## [Unreleased]

### Added

- Added an operator-only BearClaw Runs viewer under `/agent/runs` with a recent-runs index, run detail timeline, and a browser SSE consumer that replays/tails live tool-call events through the Rails app without exposing BearClaw bearer headers to the browser.
- Added graceful unavailable states for the Runs pages when BearClaw cannot be reached, plus regression coverage for the login → list runs → open run flow and HTML redaction of rendered run artifacts.
- Added an operator-only Tardigrade transcript viewer under `/agent/transcripts` with recent redacted transcript history, transcript detail pages, and regression coverage for the login → list transcripts → open transcript flow.

### Changed

- Updated `KodiakClient` to use the versioned `/api/v1/` path prefix, unwrap the Kodiak v1 response envelope (`{"data": ..., "error": null, "meta": {...}}`), extract human-readable messages from error envelopes, and propagate `X-BearClaw-Actor` / `X-BearClaw-Role` headers from `current_user` on every request. `strategies` now returns the inner array directly so views receive the expected shape. `base_controller.rb` passes `current_user.email` and role to the client constructor.
- BearClaw operator login now issues a scoped HS256 Tardigrade identity token into the Rails session, and BearClaw client calls now preserve configured edge base paths so `BEARCLAW_URL` can target the `/bearclaw` mount instead of talking straight to the private loopback port.
- Moved BearClawWeb host port from `3001` to `6701`; updated `config/environments/production.rb` `config.hosts` to allow `127.0.0.1:6701` to align with the homelab port scheme. Updated `blink.toml` (target + service port, port-published verify regex), `deploy/blink/provision_bearclaw_web.sh` (PORT variable), `BLINK.md`, and `CLAUDE.md`. Tardigrade's `blink.toml` verify check updated to match.
- Standardized the repository documentation contract and documented the project-local Blink deployment in `BLINK.md`.
- Stopped pinning the production BearClaw container to `192.168.86.53` for DNS and added a Blink verify check for Google OAuth DNS resolution from inside the container.
- Ignored the repository-root `blink.toml` and `BLINK.md` and stopped tracking them so homelab-specific Blink targets and operator notes stay local-only.
