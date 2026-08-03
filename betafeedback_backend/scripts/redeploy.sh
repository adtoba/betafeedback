#!/usr/bin/env bash
# Pull latest code, rebuild the API binary, and restart the systemd service
# with downtime limited to the process restart.
#
# Usage (on the VPS, from anywhere):
#   /opt/.../betafeedback_backend/scripts/redeploy.sh
#   make redeploy
#
# Optional env:
#   SERVICE_NAME   systemd unit name (default: betafeedback)
#   HEALTH_URL     health check URL (default: http://127.0.0.1:8080/healthz)
#   BRANCH         git branch to pull (default: current branch)

set -euo pipefail

SERVICE_NAME="${SERVICE_NAME:-betafeedback}"
HEALTH_URL="${HEALTH_URL:-http://127.0.0.1:8080/healthz}"
HEALTH_RETRIES="${HEALTH_RETRIES:-15}"
HEALTH_DELAY_SECS="${HEALTH_DELAY_SECS:-1}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKEND_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
REPO_ROOT="$(git -C "${BACKEND_DIR}" rev-parse --show-toplevel)"
BRANCH="${BRANCH:-$(git -C "${REPO_ROOT}" rev-parse --abbrev-ref HEAD)}"

log() { printf '=> %s\n' "$*"; }
die() { printf 'error: %s\n' "$*" >&2; exit 1; }

systemctl_cmd() {
  if [[ "$(id -u)" -eq 0 ]]; then
    systemctl "$@"
  else
    sudo systemctl "$@"
  fi
}

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || die "missing required command: $1"
}

require_cmd git
require_cmd go
require_cmd systemctl
require_cmd curl

cd "${REPO_ROOT}"
log "repo: ${REPO_ROOT}"
log "backend: ${BACKEND_DIR}"
log "branch: ${BRANCH}"

if [[ -n "$(git status --porcelain)" ]]; then
  die "working tree has local changes; commit, stash, or discard them before redeploying"
fi

log "pulling origin/${BRANCH}"
git fetch --prune origin
git pull --ff-only origin "${BRANCH}"

cd "${BACKEND_DIR}"
log "building bin/server"
mkdir -p bin
go build -o bin/server ./cmd/server
chmod +x bin/server

log "restarting ${SERVICE_NAME}.service"
systemctl_cmd restart "${SERVICE_NAME}"

log "waiting for ${HEALTH_URL}"
ok=0
for ((i = 1; i <= HEALTH_RETRIES; i++)); do
  if curl -fsS --max-time 2 "${HEALTH_URL}" >/dev/null 2>&1; then
    ok=1
    break
  fi
  sleep "${HEALTH_DELAY_SECS}"
done

if [[ "${ok}" -ne 1 ]]; then
  printf '\nService failed health check. Recent logs:\n' >&2
  systemctl_cmd status "${SERVICE_NAME}" --no-pager || true
  journalctl -u "${SERVICE_NAME}" -n 40 --no-pager || true
  die "health check failed after ${HEALTH_RETRIES} attempts"
fi

log "redeploy complete — $(curl -fsS --max-time 2 "${HEALTH_URL}")"
systemctl_cmd --no-pager --full status "${SERVICE_NAME}" | head -n 12 || true
