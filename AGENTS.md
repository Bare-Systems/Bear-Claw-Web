# BearClawWeb Agent Guide

Scope: the `BearClawWeb` repository.

## Purpose

BearClawWeb is the Rails operator UI for the BareSystems stack. Agent changes here should preserve:

- clear service boundaries to BearClaw, Koala, Polar, and Ursa
- stable operator-facing auth and error behavior
- the documented homelab network contract

## Workflow

- Keep active unfinished work in the workspace root `ROADMAP.md`.
- Keep deployment details in `BLINK.md`, not scattered across extra docs.
- Update `CHANGELOG.md` for meaningful shipped or in-progress changes.

## Validation

Preferred validation loop:

```bash
bundle exec rails test
```
