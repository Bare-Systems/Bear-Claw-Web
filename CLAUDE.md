# BearClawWeb Claude Context

BearClawWeb is the human-facing Rails UI in the BareSystems stack.

## Core Dependencies

- BearClaw for agent-driven workflows
- Koala for home-state and camera data
- Polar for environmental data
- Ursa major.web for security operations

## Operating Rules

- Respect the documented network boundaries in `README.md` and `BLINK.md`.
- Keep active roadmap work in the workspace root `ROADMAP.md`.
- Keep this repo limited to the canonical documentation set.

## Validation

```bash
bundle exec rails test
```
