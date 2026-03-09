#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
AI_SPACE_DIR="${AI_SPACE_DIR:-$(cd "$REPO_ROOT/.." && pwd)}"

cd "$REPO_ROOT"

echo "[deploy] sync ai-space context -> picoclaw_store"
AI_SPACE_DIR="$AI_SPACE_DIR" "$REPO_ROOT/scripts/sync_ai_space_context.sh"

echo "[deploy] docker compose up picoclaw"
AI_SPACE_DIR="$AI_SPACE_DIR" docker compose up -d --build picoclaw

echo "[deploy] done"
