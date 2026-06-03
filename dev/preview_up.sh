#!/usr/bin/env bash
# Dev-only: bring up BearClawWeb locally against mock services for visual preview.
# Builds Tailwind once, starts the stdlib mock services, then runs Rails in the
# foreground (so the preview tool can manage the process lifecycle).
set -euo pipefail
cd "$(dirname "$0")/.."

export KOALA_URL="http://127.0.0.1:8082"
export KOALA_TOKEN="dev"
export POLAR_URL="http://127.0.0.1:6703"
export POLAR_TOKEN="dev"
export PORT="3000"

bin/rails tailwindcss:build

# Start mocks in the background; clean them up when Rails exits.
ruby dev/mock_services.rb &
MOCK_PID=$!
trap 'kill "$MOCK_PID" 2>/dev/null || true' EXIT

exec bin/rails server -p "$PORT"
