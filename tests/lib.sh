#!/usr/bin/env bash
# Tiny assertion helpers shared by the harness's own shell tests. No external dependencies.

PASS=0
FAIL=0
# shellcheck disable=SC2034  # used by the test files that source this
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
TMP_ROOT="$(mktemp -d)"
trap 'rm -rf "$TMP_ROOT"' EXIT

new_dir() { local d; d="$(mktemp -d "$TMP_ROOT/case.XXXXXX")"; echo "$d"; }

ok() { PASS=$((PASS + 1)); echo "  ok   $1"; }
bad() { FAIL=$((FAIL + 1)); echo "  FAIL $1"; [[ -z "${2:-}" ]] || echo "       $2"; }

assert_file() { [[ -f "$1" ]] && ok "$2" || bad "$2" "missing file: $1"; }
assert_no_file() { [[ ! -e "$1" ]] && ok "$2" || bad "$2" "unexpected path: $1"; }
assert_contains() { grep -qF -- "$2" "$1" 2>/dev/null && ok "$3" || bad "$3" "'$2' not found in $1"; }
assert_not_contains() { ! grep -qF -- "$2" "$1" 2>/dev/null && ok "$3" || bad "$3" "'$2' unexpectedly found in $1"; }
assert_eq() { [[ "$1" == "$2" ]] && ok "$3" || bad "$3" "expected '$2', got '$1'"; }
assert_out_contains() { grep -qF -- "$2" <<<"$1" && ok "$3" || bad "$3" "'$2' not in output"; }
assert_out_lacks() { ! grep -qF -- "$2" <<<"$1" && ok "$3" || bad "$3" "'$2' unexpectedly in output"; }

finish() {
  echo "passed: $PASS  failed: $FAIL"
  [[ $FAIL -eq 0 ]]
}
