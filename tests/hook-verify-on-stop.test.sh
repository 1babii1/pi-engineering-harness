#!/usr/bin/env bash
# Behavior tests for hooks/verify-on-stop.sh: build a throwaway git repo, point
# HARNESS_VERIFY_SCRIPT at a stub that can PASS/FAIL/NOT RUN/hang on command, and assert the
# hook's exit code and (for a failure) that it surfaces the log tail.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."
# shellcheck source=tests/lib.sh
source tests/lib.sh

HOOK="$ROOT_DIR/hooks/verify-on-stop.sh"

new_repo() {
  local d; d="$(new_dir)"
  git -C "$d" init -q
  git -C "$d" -c user.email=t@t -c user.name=t commit -q --allow-empty -m init
  echo "$d"
}

enable_repo() { # enable_repo <dir> <verify-behavior: pass|fail|notrun|hang>
  mkdir -p "$1/.pi/project"
  cat > "$1/.pi/project/commands.sh" <<EOF
export HARNESS_VERIFY_ON_STOP=1
export HARNESS_VERIFY_SCRIPT="$1/fake-verify.sh"
EOF
  case "$2" in
    pass)   printf '#!/bin/sh\nexit 0\n' > "$1/fake-verify.sh" ;;
    fail)   printf '#!/bin/sh\necho "boom: assertion failed on line 42"\nexit 1\n' > "$1/fake-verify.sh" ;;
    notrun) printf '#!/bin/sh\nexit 2\n' > "$1/fake-verify.sh" ;;
    hang)   printf '#!/bin/sh\nsleep 30\n' > "$1/fake-verify.sh" ;;
  esac
  chmod +x "$1/fake-verify.sh"
  # Commit the fixtures so only what a test adds afterwards counts as a change.
  git -C "$1" add -A
  git -C "$1" -c user.email=t@t -c user.name=t commit -q -m fixtures
}

run_hook() { # run_hook <dir> [stop_hook_active-json] -> exit code
  local d="$1" payload='{}'   # (not ${2:-{}}: bash appends a stray "}" when $2 is set)
  [[ $# -lt 2 ]] || payload="$2"
  local rc=0
  ( cd "$d" && printf '%s' "$payload" | "$HOOK" >/tmp/stop-hook.out 2>/tmp/stop-hook.err ) || rc=$?
  echo "$rc"
}

# --- off by default ---------------------------------------------------------------------------
T1="$(new_repo)"
echo x > "$T1/new-file.txt"
rc="$(run_hook "$T1")"
assert_eq "$rc" "0" "with no HARNESS_VERIFY_ON_STOP, the hook is a no-op even with changes"

# --- nothing changed -> skipped even when enabled ---------------------------------------------
T2="$(new_repo)"
enable_repo "$T2" fail
rc="$(run_hook "$T2")"
assert_eq "$rc" "0" "an empty diff is not verified, even when enabled"

# --- changed + enabled + passing verify ---------------------------------------------------
T3="$(new_repo)"
enable_repo "$T3" pass
echo x > "$T3/new-file.txt"
rc="$(run_hook "$T3")"
assert_eq "$rc" "0" "a passing verify.sh lets the turn end"

# --- changed + enabled + failing verify ---------------------------------------------------
T4="$(new_repo)"
enable_repo "$T4" fail
echo x > "$T4/new-file.txt"
rc="$(run_hook "$T4")"
assert_eq "$rc" "2" "a failing verify.sh blocks the turn"
assert_contains "/tmp/stop-hook.err" "boom: assertion failed" "the failure log tail is surfaced to the model"

# --- NOT RUN (exit 2 from verify.sh) never blocks -----------------------------------------
T5="$(new_repo)"
enable_repo "$T5" notrun
echo x > "$T5/new-file.txt"
rc="$(run_hook "$T5")"
assert_eq "$rc" "0" "verify.sh NOT RUN (exit 2) does not block the turn"

# --- stop_hook_active short-circuits, even with a failing verify --------------------------
T6="$(new_repo)"
enable_repo "$T6" fail
echo x > "$T6/new-file.txt"
rc="$(run_hook "$T6" '{"stop_hook_active": true}')"
assert_eq "$rc" "0" "stop_hook_active=true skips re-running verification (no infinite loop)"

# --- timeout is enforced, not left to hang -------------------------------------------------
T7="$(new_repo)"
enable_repo "$T7" hang
echo x > "$T7/new-file.txt"
rc=0
( cd "$T7" && HARNESS_VERIFY_ON_STOP_TIMEOUT=1 bash -c 'printf "{}" | "'"$HOOK"'"' >/tmp/stop-hook.out 2>/tmp/stop-hook.err ) || rc=$?
assert_eq "$rc" "0" "a hung verify.sh times out and does not block (surfaces a warning instead)"

# --- regressions from the independent verification ---------------------------------------------
T8="$(new_repo)"
enable_repo "$T8" fail
mkdir -p "$T8/sub/dir"; echo x > "$T8/sub/dir/f.txt"
rc=0; ( cd "$T8/sub/dir" && printf '{}' | CLAUDE_PROJECT_DIR="$T8" "$HOOK" >/dev/null 2>&1 ) || rc=$?
assert_eq "$rc" "2" "run from a subdirectory, the hook still verifies via CLAUDE_PROJECT_DIR"

T9="$(new_repo)"
enable_repo "$T9" pass
printf 'export HARNESS_VERIFY_ON_STOP=1\nexport HARNESS_VERIFY_SCRIPT="%s/fake-verify.sh"\nfalse\necho "$UNSET_VAR_XYZ"\n' "$T9" > "$T9/.pi/project/commands.sh"
git -C "$T9" add -A; git -C "$T9" -c user.email=t@t -c user.name=t commit -q -m cmds
echo x > "$T9/new-file.txt"
rc="$(run_hook "$T9")"
assert_eq "$rc" "0" "a commands.sh that fails or uses unset vars does not kill the hook"

T10="$(new_repo)"
enable_repo "$T10" pass
rm -f "$T10/fake-verify.sh"
echo x > "$T10/new-file.txt"
rc="$(run_hook "$T10")"
assert_eq "$rc" "0" "a missing verify script warns instead of blocking"
assert_contains "/tmp/stop-hook.err" "not found" "the missing-script warning is shown"

finish
