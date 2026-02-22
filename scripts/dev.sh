#!/usr/bin/env bash
set -euo pipefail

export ENV="${ENV:-dev}"

cleanup() {
  local pids
  pids="$(jobs -pr || true)"
  if [[ -n "$pids" ]]; then
    kill $pids >/dev/null 2>&1 || true
  fi
}
trap cleanup EXIT INT TERM

npm run tailwind:watch &
npm run client:watch &

npm run server:dev
