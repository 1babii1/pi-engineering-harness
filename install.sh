#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET="${TARGET:-$PWD}"
AGENT="pi"

usage() {
  cat <<USAGE
Usage:
  ./install.sh [--agent pi|codex|claude|cursor] <profile|skill> [profile|skill ...]

Examples:
  ./install.sh backend
  ./install.sh fullstack production
  ./install.sh --agent claude fullstack
  TARGET=/path/to/project ./install.sh frontend audit/frontend
USAGE
}

args=()
while [[ $# -gt 0 ]]; do
  case "$1" in
    --agent) AGENT="${2:-}"; shift 2;;
    -h|--help) usage; exit 0;;
    *) args+=("$1"); shift;;
  esac
done

[[ ${#args[@]} -gt 0 ]] || { usage; exit 1; }
case "$AGENT" in pi|codex|claude|cursor) ;; *) echo "Unknown agent: $AGENT" >&2; exit 2;; esac

mkdir -p "$TARGET/.pi/skills" "$TARGET/.pi/prompts" "$TARGET/.pi/references" "$TARGET/.pi/laws" "$TARGET/.pi/project" "$TARGET/.pi/work" "$TARGET/.pi/learnings" "$TARGET/.harness/scripts" "$TARGET/.harness/templates"
cp "$ROOT_DIR/AGENTS.md" "$TARGET/AGENTS.md"
cp -R "$ROOT_DIR/.pi/prompts/." "$TARGET/.pi/prompts/"
cp -R "$ROOT_DIR/.pi/references/." "$TARGET/.pi/references/"
cp -R "$ROOT_DIR/.pi/laws/." "$TARGET/.pi/laws/"
for src in "$ROOT_DIR"/templates/project-context/*.md; do
  dst="$TARGET/.pi/project/$(basename "$src")"
  [[ -f "$dst" ]] || cp "$src" "$dst"
done
cp "$ROOT_DIR/.pi/work/README.md" "$TARGET/.pi/work/README.md"
[[ -f "$TARGET/.pi/learnings/inbox.md" ]] || cp "$ROOT_DIR/.pi/learnings/inbox.md" "$TARGET/.pi/learnings/inbox.md"
cp -R "$ROOT_DIR/scripts/." "$TARGET/.harness/scripts/"
cp "$ROOT_DIR/templates/scope-contract.md" "$TARGET/.harness/templates/scope-contract.md"
cp "$ROOT_DIR/templates/adr.md" "$TARGET/.harness/templates/adr.md"
cp "$ROOT_DIR/templates/proof-obligations.md" "$TARGET/.harness/templates/proof-obligations.md"

declare -A SELECTED=()
add_skill() {
  local skill="$1"
  local src="$ROOT_DIR/.pi/skills/$skill"
  [[ -d "$src" ]] || { echo "Unknown skill: $skill" >&2; exit 2; }
  SELECTED["$skill"]=1
}
expand_arg() {
  local arg="$1" profile="$ROOT_DIR/profiles/$arg"
  if [[ -f "$profile" ]]; then
    while IFS= read -r line || [[ -n "$line" ]]; do
      [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]] && continue
      add_skill "$line"
    done < "$profile"
  else
    add_skill "$arg"
  fi
}
for arg in "${args[@]}"; do expand_arg "$arg"; done
for skill in "${!SELECTED[@]}"; do
  mkdir -p "$TARGET/.pi/skills/$(dirname "$skill")"
  rm -rf "$TARGET/.pi/skills/$skill"
  cp -R "$ROOT_DIR/.pi/skills/$skill" "$TARGET/.pi/skills/$skill"
done

case "$AGENT" in
  pi|codex) : ;;
  claude) cp "$ROOT_DIR/adapters/claude/CLAUDE.md" "$TARGET/CLAUDE.md" ;;
  cursor)
    mkdir -p "$TARGET/.cursor/rules"
    cat > "$TARGET/.cursor/rules/engineering-harness.mdc" <<'CURSOR'
---
description: Shared engineering harness. See repository AGENTS.md for the source of truth.
alwaysApply: true
---
Follow the repository's AGENTS.md and the narrowest applicable project-scoped instructions. Do not duplicate or override them without a repository-specific reason.
CURSOR
    ;;
esac

echo "Installed ${#SELECTED[@]} skills into: $TARGET (agent: $AGENT)"
printf ' - %s\n' "${!SELECTED[@]}" | sort
