#!/usr/bin/env bash
set -euo pipefail

# One-command deploy for private picoclaw repo.
# Default mode: build locally, copy image to EC2, restart service.

MODE="${MODE:-local-copy}"
SYNC_UPSTREAM="${SYNC_UPSTREAM:-1}"

while [ $# -gt 0 ]; do
  case "$1" in
    --mode)
      MODE="$2"
      shift 2
      ;;
    --no-sync)
      SYNC_UPSTREAM="0"
      shift
      ;;
    *)
      echo "unknown arg: $1"
      echo "usage: $0 [--mode local-copy|build-on-ec2] [--no-sync]"
      exit 2
      ;;
  esac
done

SSH_KEY="${SSH_KEY:-/Users/amiyakumar.m/Ws/ssh/apps-magic-ec2.pem}"
EC2_HOST="${EC2_HOST:-ubuntu@44.204.150.112}"
AI_SPACE_DIR="${AI_SPACE_DIR:-/home/ubuntu/Ws/ai-space}"
REPO_DIR="${REPO_DIR:-$(cd "$(dirname "$0")/.." && pwd)}"
IMAGE_NAME="${IMAGE_NAME:-picoclaw-picoclaw:latest}"

sync_upstream_main() {
  if [ "$SYNC_UPSTREAM" != "1" ]; then
    return 0
  fi
  if ! command -v gh >/dev/null 2>&1; then
    echo "[sync] gh not found; skipping workflow sync"
    return 0
  fi

  local repo="amiyak-codespace/picoclaw-private"
  echo "[sync] triggering upstream sync workflow for ${repo}"
  gh workflow run "Upstream Sync PR" -R "$repo" >/dev/null || true
  sleep 2
  local run_id
  run_id="$(gh run list -R "$repo" --workflow "Upstream Sync PR" --limit 1 --json databaseId --jq '.[0].databaseId' 2>/dev/null || true)"
  if [ -n "${run_id:-}" ]; then
    gh run watch "$run_id" -R "$repo" --interval 3 || true
  fi
  local pr
  pr="$(gh pr list -R "$repo" --state open --head upstream-sync --json number --jq '.[0].number' 2>/dev/null || true)"
  if [ -n "${pr:-}" ]; then
    echo "[sync] merging upstream PR #$pr"
    gh pr merge "$pr" -R "$repo" --squash --delete-branch --admin || true
  fi
}

sync_upstream_main

if [ "$MODE" = "build-on-ec2" ]; then
  ssh -i "$SSH_KEY" "$EC2_HOST" "set -e; cd $AI_SPACE_DIR/picoclaw; git fetch origin --prune; git checkout main; git reset --hard origin/main; AI_SPACE_DIR=$AI_SPACE_DIR ./scripts/deploy_picoclaw_with_context.sh"
else
  cd "$REPO_DIR"
  git fetch origin --prune
  git checkout main
  git reset --hard origin/main
  docker buildx build --platform linux/amd64 -t "$IMAGE_NAME" --load .
  docker save "$IMAGE_NAME" | ssh -i "$SSH_KEY" "$EC2_HOST" 'docker load'
  ssh -i "$SSH_KEY" "$EC2_HOST" "set -e; cd $AI_SPACE_DIR/picoclaw; git fetch origin --prune; git checkout main; git reset --hard origin/main; AI_SPACE_DIR=$AI_SPACE_DIR ./scripts/sync_ai_space_context.sh; AI_SPACE_DIR=$AI_SPACE_DIR docker compose up -d --no-build --force-recreate picoclaw"
fi

ssh -i "$SSH_KEY" "$EC2_HOST" "set -e; docker ps --format 'table {{.Names}}\t{{.Status}}\t{{.Image}}'; echo; curl -s -o /dev/null -w 'HEALTH=%{http_code} READY=' http://localhost:18790/health; curl -s -o /dev/null -w '%{http_code}\n' http://localhost:18790/ready"
