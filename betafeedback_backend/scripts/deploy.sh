#!/usr/bin/env bash
# Run from your Mac: push local commits, SSH into the VPS, pull, rebuild,
# and restart the API service.
#
# Setup (once):
#   cp .deploy.env.example .deploy.env
#   # edit DEPLOY_HOST / DEPLOY_PATH
#
# Usage:
#   ./scripts/deploy.sh
#   make deploy
#
# Optional env / .deploy.env:
#   DEPLOY_HOST   e.g. root@203.0.113.10  (required)
#   DEPLOY_PATH   backend dir on the VPS
#   PUSH          1 to git push first (default), 0 to skip
#   BRANCH        branch to push/pull (default: current)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKEND_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
REPO_ROOT="$(git -C "${BACKEND_DIR}" rev-parse --show-toplevel)"

if [[ -f "${BACKEND_DIR}/.deploy.env" ]]; then
  # shellcheck disable=SC1091
  set -a
  source "${BACKEND_DIR}/.deploy.env"
  set +a
fi

DEPLOY_HOST="${DEPLOY_HOST:-}"
DEPLOY_PATH="${DEPLOY_PATH:-/opt/betafeedback/betafeedback/betafeedback_backend}"
PUSH="${PUSH:-1}"
BRANCH="${BRANCH:-$(git -C "${REPO_ROOT}" rev-parse --abbrev-ref HEAD)}"

log() { printf '=> %s\n' "$*"; }
die() { printf 'error: %s\n' "$*" >&2; exit 1; }

[[ -n "${DEPLOY_HOST}" ]] || die "DEPLOY_HOST is not set. Copy .deploy.env.example to .deploy.env and fill it in."

command -v git >/dev/null || die "missing git"
command -v ssh >/dev/null || die "missing ssh"

cd "${REPO_ROOT}"
log "local branch: ${BRANCH}"
log "remote host: ${DEPLOY_HOST}"
log "remote path: ${DEPLOY_PATH}"

if [[ -n "$(git status --porcelain)" ]]; then
  die "local working tree has uncommitted changes; commit or stash before deploying"
fi

if [[ "${PUSH}" == "1" ]]; then
  log "pushing origin/${BRANCH}"
  git push -u origin "${BRANCH}"
else
  log "skipping git push (PUSH=0)"
fi

log "running remote redeploy over SSH"
ssh -o BatchMode=yes -o StrictHostKeyChecking=accept-new "${DEPLOY_HOST}" \
  "set -euo pipefail
   cd '${DEPLOY_PATH}'
   export BRANCH='${BRANCH}'
   if [[ ! -x scripts/redeploy.sh ]]; then
     chmod +x scripts/redeploy.sh
   fi
   ./scripts/redeploy.sh"

log "deploy finished"
