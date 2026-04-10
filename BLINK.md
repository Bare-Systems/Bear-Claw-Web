# BearClawWeb Blink Contract

This file documents the real behavior of [`blink.toml`](/Users/joecaruso/Projects/BareSystems/BearClawWeb/blink.toml).

## Targets

- `homelab`: SSH deploy target on host `blink`, user `admin`, runtime dir `/home/admin/baresystems/runtime/bearclaw-web`
- `local`: local helper target with a production-like database URL for local workflows

## Services

### `bearclaw-web`

- Build: Docker image is built locally for `linux/amd64`, tagged, and pushed to `registry.home:5000`
- Transport artifact: `dist/.pushed`
- Deploy pipeline: `fetch_artifact`, `provision`, `remote_script`, `stop`, `start`, `health_check`, `verify`
- Runtime shape: container bound to `127.0.0.1:6701`, proxied by Tardigrade
- Runtime DNS: container uses Docker's default resolver configuration; BearClaw no longer pins container DNS to `192.168.86.53`
- Provisioning seeds the runtime env file on first deploy and creates runtime directories
- Remote script provisions Postgres and the Tardigrade vhost

### `bearclaw-web-migrate`

- Purpose: run Rails migrations and seeds inside the running container
- Pipeline: `shell`
- Usage: deploy this service only when schema changes need to be applied

## Verification

The manifest verifies:

- Rails health endpoint
- container running state
- published port mapping
- host reachability for Koala, Polar, and Ursa
- container-to-service reachability for Koala, Polar, and Ursa
- authorized Koala MCP access from inside the container
- BearClaw chat reachability through the public hostname
- Google OAuth DNS resolution from inside the container

## Operator Notes

- Keep BearClawWeb loopback-only on `127.0.0.1:6701`.
- Do not use host loopback for Koala, Polar, or Ursa from inside the container.
- Update this file whenever env seeding, image transport, verification coverage, or network assumptions change.
