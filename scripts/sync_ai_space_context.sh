#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
AI_SPACE_DIR="${AI_SPACE_DIR:-$(cd "$REPO_ROOT/.." && pwd)}"
PICO_STORE_DIR="${PICO_STORE_DIR:-$AI_SPACE_DIR/picoclaw_store}"
CODEX_HOME_DIR="${CODEX_HOME:-$HOME/.codex}"

TARGET_WS="$PICO_STORE_DIR/workspace"
TARGET_SKILLS="$TARGET_WS/skills"
TARGET_MEMORY="$TARGET_WS/memory"

echo "[sync] repo=$REPO_ROOT"
echo "[sync] ai_space=$AI_SPACE_DIR"
echo "[sync] store=$PICO_STORE_DIR"

mkdir -p "$TARGET_SKILLS" "$TARGET_MEMORY" "$TARGET_MEMORY/ai-space" "$TARGET_SKILLS/codex-system"

# Keep runtime skills updated from repo workspace skills.
if [ -d "$REPO_ROOT/workspace/skills" ]; then
  rsync -a "$REPO_ROOT/workspace/skills/" "$TARGET_SKILLS/"
fi

# Add ai-space memory snapshots as deploy context.
if [ -d "$AI_SPACE_DIR/memory" ]; then
  rsync -a --delete "$AI_SPACE_DIR/memory/" "$TARGET_MEMORY/ai-space/"
fi

# Add Codex coding skills (if present) to runtime skill set.
if [ -d "$CODEX_HOME_DIR/skills/.system" ]; then
  rsync -a --delete "$CODEX_HOME_DIR/skills/.system/" "$TARGET_SKILLS/codex-system/"
fi

echo "[sync] done"
