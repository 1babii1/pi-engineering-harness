#!/usr/bin/env bash
# Stop hook: run the project's quick verification before Claude Code finishes a turn that
# changed files. Off by default - a project opts in via HARNESS_VERIFY_ON_STOP=1 in
# .pi/project/commands.sh, since a dotnet/webpack build can take minutes and not every project
# wants that in the critical path of every turn.
#
# Reads the Stop hook JSON payload on stdin (only `stop_hook_active` is used). Exit 0 lets the
# turn end; exit 2 blocks it and feeds stderr back to Claude, which then sees the failure and
# keeps working instead of reporting done.
set -euo pipefail

# Hooks run from wherever the session's shell is; everything below is relative to the project root.
cd "${CLAUDE_PROJECT_DIR:-.}"

CMDS_FILE=".pi/project/commands.sh"
if [[ -f "$CMDS_FILE" ]]; then
  # A project-owned script may fail or reference unset variables; that must not kill this hook
  # (exit 1 is a non-blocking hook error, i.e. silently no verification).
  set +eu
  # shellcheck disable=SC1090
  source "$CMDS_FILE"
  set -eu
fi

[[ "${HARNESS_VERIFY_ON_STOP:-0}" == "1" ]] || exit 0

# stop_hook_active is true when Claude Code is already resuming from a previous Stop-hook
# block in this same turn. Re-running verification here would either loop forever (still
# failing) or double-run it for no reason (already fixed, diff unchanged); either way this
# hook already had its one say for this turn.
payload="$(cat 2>/dev/null || true)"
if command -v python3 >/dev/null 2>&1 && [[ -n "$payload" ]]; then
  active="$(printf '%s' "$payload" | python3 -c 'import json,sys
try:
    d = json.load(sys.stdin)
except Exception:
    d = {}
print("1" if d.get("stop_hook_active") else "0")' 2>/dev/null || echo 0)"
  [[ "$active" == "1" ]] && exit 0
fi

# Nothing changed -> nothing to verify (e.g. the turn only answered a question).
changed="$(git diff --name-only HEAD 2>/dev/null || true)$(git diff --name-only --cached 2>/dev/null || true)$(git ls-files --others --exclude-standard 2>/dev/null || true)"
[[ -n "$changed" ]] || exit 0

VERIFY_SCRIPT="${HARNESS_VERIFY_SCRIPT:-.harness/scripts/verify.sh}"
if [[ ! -f "$VERIFY_SCRIPT" ]]; then
  # A setup gap the model cannot fix by editing code: warn, never block (same as NOT RUN).
  echo "verify-on-stop: $VERIFY_SCRIPT not found; nothing verified. Reinstall the harness or set HARNESS_VERIFY_SCRIPT." >&2
  exit 0
fi
[[ -x "$VERIFY_SCRIPT" ]] || VERIFY_SCRIPT="bash $VERIFY_SCRIPT"
TIMEOUT="${HARNESS_VERIFY_ON_STOP_TIMEOUT:-300}"

log="$(mktemp)"
trap 'rm -f "$log"' EXIT

# `|| rc=$?` keeps a failing verification from tripping `set -e` before the exit code is read.
rc=0
if command -v timeout >/dev/null 2>&1; then
  timeout "$TIMEOUT" bash -c "$VERIFY_SCRIPT quick" >"$log" 2>&1 || rc=$?
else
  bash -c "$VERIFY_SCRIPT quick" >"$log" 2>&1 || rc=$?
fi

case "$rc" in
  0) exit 0 ;;
  2)
    # NOT RUN: no verification command configured for what changed. Do not block on this -
    # it's a gap to close in .pi/project/commands.sh, not a failure the model can fix by editing code.
    echo "verify.sh quick: NOT RUN (nothing to verify automatically here)." >&2
    exit 0
    ;;
  124)
    echo "verify.sh quick timed out after ${TIMEOUT}s. Raise HARNESS_VERIFY_ON_STOP_TIMEOUT in .pi/project/commands.sh if this is expected, or narrow what quick checks." >&2
    exit 0
    ;;
  *)
    echo "verify.sh quick FAILED before this turn could end:" >&2
    tail -n 40 "$log" >&2
    exit 2
    ;;
esac
