# Changelog

All notable changes to BearClawWeb are documented here.

## [Unreleased]

### Changed

- Moved BearClawWeb host port from `3001` to `6701`; updated `config/environments/production.rb` `config.hosts` to allow `127.0.0.1:6701` to align with the homelab port scheme. Updated `blink.toml` (target + service port, port-published verify regex), `deploy/blink/provision_bearclaw_web.sh` (PORT variable), `BLINK.md`, and `CLAUDE.md`. Tardigrade's `blink.toml` verify check updated to match.
- Standardized the repository documentation contract and documented the project-local Blink deployment in `BLINK.md`.
- Stopped pinning the production BearClaw container to `192.168.86.53` for DNS and added a Blink verify check for Google OAuth DNS resolution from inside the container.
