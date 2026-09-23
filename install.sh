#!/usr/bin/env bash
# Installs the harness (shared prompts/laws/scripts + selected skills) into a target project.
#
# Ownership model:
#   harness-owned  .pi/prompts, .pi/laws, .pi/references, .pi/work/README.md, .harness/*,
#                  selected .pi/skills/*  -> refreshed on every run; anything that differs is
#                  backed up first, never silently destroyed.
#   project-owned  AGENTS.md, CLAUDE.md, GEMINI.md, .cursor rule -> created if absent; if present and
#                  different they are LEFT ALONE unless --overwrite-entry is given (then backed up).
#   project data   .pi/project/*, .pi/learnings/inbox.md -> created only if absent, never touched.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
TARGET="${TARGET:-$PWD}"
AGENT="pi"
DRY_RUN=0
OVERWRITE_ENTRY=0

usage() {
  cat <<USAGE
Usage:
  ./install.sh [--agent pi|codex|claude|cursor|gemini] [--dry-run] [--overwrite-entry] <profile|skill> [...]

Options:
  --dry-run          Print what would change; write nothing.
  --overwrite-entry  Also replace an existing, different AGENTS.md / CLAUDE.md / GEMINI.md / Cursor rule
                     (the old file is backed up). Without it those files are kept.

The target is \$TARGET (default: current directory). Replaced files are backed up under
\$TARGET/.harness/backup/<timestamp>/.

Examples:
  ./install.sh backend
  ./install.sh fullstack production
  ./install.sh --agent claude fullstack
  TARGET=/path/to/project ./install.sh --dry-run frontend audit/frontend
USAGE
}

args=()
while [[ $# -gt 0 ]]; do
  case "$1" in
    --agent) [[ $# -ge 2 ]] || { echo "--agent needs a value" >&2; exit 2; }; AGENT="$2"; shift 2;;
    --dry-run) DRY_RUN=1; shift;;
    --overwrite-entry) OVERWRITE_ENTRY=1; shift;;
    -h|--help) usage; exit 0;;
    -*) echo "Unknown option: $1" >&2; usage >&2; exit 2;;
    *) args+=("$1"); shift;;
  esac
done

[[ ${#args[@]} -gt 0 ]] || { usage >&2; exit 1; }
case "$AGENT" in pi|codex|claude|cursor|gemini) ;; *) echo "Unknown agent: $AGENT" >&2; exit 2;; esac

[[ -d "$TARGET" ]] || { echo "Target directory does not exist: $TARGET" >&2; exit 2; }
TARGET="$(cd "$TARGET" && pwd -P)"
if [[ "$TARGET" == "$ROOT_DIR" ]]; then
  echo "Refusing to install the harness into itself ($TARGET). Set TARGET=/path/to/project." >&2
  exit 2
fi

# Resolve and validate every requested skill BEFORE writing anything, so a typo cannot leave a
# half-installed target behind.
declare -A SELECTED=()
add_skill() {
  [[ -f "$ROOT_DIR/.pi/skills/$1/SKILL.md" ]] || { echo "Unknown skill: $1" >&2; exit 2; }
  SELECTED["$1"]=1
}
for arg in "${args[@]}"; do
  if [[ -f "$ROOT_DIR/profiles/$arg" ]]; then
    while IFS= read -r line || [[ -n "$line" ]]; do
      line="${line%$'\r'}"
      [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]] && continue
      add_skill "$line"
    done < "$ROOT_DIR/profiles/$arg"
  else
    add_skill "$arg"
  fi
done
mapfile -t SKILLS < <(printf '%s\n' "${!SELECTED[@]}" | sort)

STAMP="$(date -u +%Y%m%dT%H%M%SZ)"
BACKUP_DIR="$TARGET/.harness/backup/$STAMP"
created=(); updated=(); kept=(); removed=(); unchanged=0

run() { [[ $DRY_RUN -eq 1 ]] || "$@"; }

backup() { # backup <absolute path inside TARGET>
  local rel="${1#"$TARGET"/}"
  run mkdir -p "$BACKUP_DIR/$(dirname "$rel")"
  run cp -p "$1" "$BACKUP_DIR/$rel"
}

# place <src> <dst> managed|entry|once
place() {
  local src="$1" dst="$2" mode="$3" rel="${2#"$TARGET"/}"
  if [[ ! -e "$dst" ]]; then
    run mkdir -p "$(dirname "$dst")"
    run cp -p "$src" "$dst"
    created+=("$rel")
  elif cmp -s "$src" "$dst"; then
    unchanged=$((unchanged + 1))
  elif [[ "$mode" == once ]] || { [[ "$mode" == entry ]] && [[ $OVERWRITE_ENTRY -eq 0 ]]; }; then
    kept+=("$rel")
  else
    backup "$dst"
    run cp -p "$src" "$dst"
    updated+=("$rel")
  fi
}

place_tree() { # place_tree <src dir> <dst dir> <mode>
  local f
  while IFS= read -r -d '' f; do
    place "$f" "$2/${f#"$1"/}" "$3"
  done < <(find "$1" -type f -print0 | sort -z)
}

# Files present in an installed harness skill but absent upstream are stale; back up, then drop
# them, so a reinstall mirrors the upstream skill (what the old `rm -rf` did, but recoverable).
prune_stale() { # prune_stale <src dir> <dst dir>
  local f
  [[ -d "$2" ]] || return 0
  while IFS= read -r -d '' f; do
    if [[ ! -e "$1/${f#"$2"/}" ]]; then
      backup "$f"
      run rm -f "$f"
      removed+=("${f#"$TARGET"/}")
    fi
  done < <(find "$2" -type f -print0 | sort -z)
}

place "$ROOT_DIR/AGENTS.md" "$TARGET/AGENTS.md" entry
place_tree "$ROOT_DIR/.pi/prompts" "$TARGET/.pi/prompts" managed
place_tree "$ROOT_DIR/.pi/references" "$TARGET/.pi/references" managed
place_tree "$ROOT_DIR/.pi/laws" "$TARGET/.pi/laws" managed
place_tree "$ROOT_DIR/templates/project-context" "$TARGET/.pi/project" once
place "$ROOT_DIR/.pi/work/README.md" "$TARGET/.pi/work/README.md" managed
place "$ROOT_DIR/.pi/learnings/inbox.md" "$TARGET/.pi/learnings/inbox.md" once
place_tree "$ROOT_DIR/scripts" "$TARGET/.harness/scripts" managed
for t in scope-contract adr proof-obligations; do
  place "$ROOT_DIR/templates/$t.md" "$TARGET/.harness/templates/$t.md" managed
done
place "$ROOT_DIR/templates/commands.sh.example" "$TARGET/.harness/templates/commands.sh.example" managed
place_tree "$ROOT_DIR/templates/nested" "$TARGET/.harness/templates/nested" managed
previous_version="$(cat "$TARGET/.harness/VERSION" 2>/dev/null || true)"
place "$ROOT_DIR/VERSION" "$TARGET/.harness/VERSION" managed

for skill in "${SKILLS[@]}"; do
  place_tree "$ROOT_DIR/.pi/skills/$skill" "$TARGET/.pi/skills/$skill" managed
  prune_stale "$ROOT_DIR/.pi/skills/$skill" "$TARGET/.pi/skills/$skill"
done

case "$AGENT" in
  pi|codex) : ;;
  claude)
    place "$ROOT_DIR/adapters/claude/CLAUDE.md" "$TARGET/CLAUDE.md" entry

    # Hooks and the verifier subagent are harness-owned and refreshed on every install.
    place_tree "$ROOT_DIR/hooks" "$TARGET/.harness/hooks" managed
    # The subagent's body is generated from the skill so the verifier procedure has one source.
    agent_tmp="$(mktemp)"
    { cat "$ROOT_DIR/adapters/claude/agents/independent-verifier.frontmatter.md"
      # body of the skill = everything after its own frontmatter block
      awk 'BEGIN{n=0} /^---$/ && n<2 {n++; next} n>=2' "$ROOT_DIR/.pi/skills/workflow/independent-verifier/SKILL.md"
    } > "$agent_tmp"
    place "$agent_tmp" "$TARGET/.claude/agents/independent-verifier.md" managed
    rm -f "$agent_tmp"

    # Merge hooks into an existing settings.json instead of replacing it (permissions etc. survive).
    settings_tmp="$(mktemp)"
    if python3 "$ROOT_DIR/adapters/claude/merge-settings.py" \
         "$TARGET/.claude/settings.json" "$ROOT_DIR/adapters/claude/settings.json" >"$settings_tmp" 2>"$settings_tmp.err"; then
      place "$settings_tmp" "$TARGET/.claude/settings.json" managed
    else
      kept+=(".claude/settings.json (NOT merged: $(head -n1 "$settings_tmp.err"); add the hooks from adapters/claude/settings.json by hand)")
    fi
    rm -f "$settings_tmp" "$settings_tmp.err"
    # Claude Code discovers skills only from .claude/skills/<name>/SKILL.md (never .pi/skills/),
    # so mirror the selected skills there under their frontmatter name, or they stay invisible.
    for skill in "${SKILLS[@]}"; do
      skill_name="$(sed -n 's/^name:[[:space:]]*//p' "$ROOT_DIR/.pi/skills/$skill/SKILL.md" | head -n1)"
      [[ -n "$skill_name" ]] || skill_name="$(basename "$skill")"
      place_tree "$ROOT_DIR/.pi/skills/$skill" "$TARGET/.claude/skills/$skill_name" managed
      prune_stale "$ROOT_DIR/.pi/skills/$skill" "$TARGET/.claude/skills/$skill_name"
    done
    ;;
  gemini) place "$ROOT_DIR/adapters/gemini/GEMINI.md" "$TARGET/GEMINI.md" entry ;;
  cursor)
    rule="$(mktemp)"
    trap 'rm -f "$rule"' EXIT
    cat > "$rule" <<'CURSOR'
---
description: Shared engineering harness. See repository AGENTS.md for the source of truth.
alwaysApply: true
---
Follow the repository's AGENTS.md and the narrowest applicable project-scoped instructions. Do not duplicate or override them without a repository-specific reason.
CURSOR
    chmod 644 "$rule"
    place "$rule" "$TARGET/.cursor/rules/engineering-harness.mdc" entry
    ;;
esac

prefix=""; [[ $DRY_RUN -eq 1 ]] && prefix="[dry-run] would have: "
new_version="$(cat "$ROOT_DIR/VERSION")"
version_note="harness $new_version"
if [[ -n "$previous_version" && "$previous_version" != "$new_version" ]]; then version_note="harness $previous_version -> $new_version"; fi
echo "${prefix}Target: $TARGET (agent: $AGENT, ${#SKILLS[@]} skills, $version_note)"
echo "  created: ${#created[@]}   updated: ${#updated[@]}   removed: ${#removed[@]}   unchanged: $unchanged   kept (project-owned/data): ${#kept[@]}"
for f in "${created[@]}"; do echo "  + $f"; done
for f in "${updated[@]}"; do echo "  ~ $f"; done
for f in "${removed[@]}"; do echo "  - $f"; done
for f in "${kept[@]}"; do
  case "$f" in
    .claude/settings.json*) echo "  ! $f";;
    AGENTS.md|CLAUDE.md|GEMINI.md|.cursor/*) echo "  = $f differs from the harness version; kept (use --overwrite-entry to replace, old copy is backed up)";;
    *) echo "  = $f kept (project data, never overwritten)";;
  esac
done
if [[ $DRY_RUN -eq 0 && $(( ${#updated[@]} + ${#removed[@]} )) -gt 0 ]]; then
  echo "  Backup of replaced/removed files: $BACKUP_DIR"
fi
echo "Skills:"
printf '  - %s\n' "${SKILLS[@]}"
