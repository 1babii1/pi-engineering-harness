#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

usage() {
  cat <<USAGE
Usage:
  $0 list [category]
  $0 grade <case-file> [diff-file]
  $0 run <case-file>

  list              List available case files (optionally filtered by category).
  grade             Deterministically grade a diff against one case's checks.
                     Reads unified diff from <diff-file>, or from \`git diff\` in the
                     current repo if omitted. Cases with checks.mode: llm-judge (or no
                     checks: block at all) report NOT RUN, not PASS - grading them needs
                     an LLM judge or a human reviewer against the case's expected/
                     forbidden prose, which this script does not attempt to fake.
  run               Invoke \$AGENT_RUN_CMD (required) with the case's task on \$1, capture
                     its diff, then grade it the same way \`grade\` does. This script does
                     not ship agent execution - AGENT_RUN_CMD is your integration point,
                     same override pattern as scripts/verify-backend.sh's
                     BACKEND_VERIFY_CMD. It is invoked as:
                       AGENT_RUN_CMD <case-file> <task-text> <scratch-workdir>
                     and must leave its produced changes in <scratch-workdir> as a git
                     diff (or committed changes \`git diff\` in that dir can see).

Examples:
  $0 list backend
  $0 grade evals/cases/backend/parameterized-query.yml
  $0 grade evals/cases/backend/parameterized-query.yml /tmp/candidate.diff
  AGENT_RUN_CMD=./my-agent-runner.sh $0 run evals/cases/backend/parameterized-query.yml
USAGE
}

# --- minimal case-file reader -------------------------------------------------------
# Deliberately not a real YAML parser: these case files are a small, flat, known
# subset (scalars, one level of nesting, simple "- item" lists), and every case in
# this repo is authored by hand to stay in that subset. A dependency-free ~10-line
# reader is more in keeping with this harness's own "no dependency without a concrete
# benefit" rule than adding a yq/python-yaml requirement for three files.

case_field() { # case_field <file> <key> -> scalar value on the same line
  sed -n "s/^${2}:[[:space:]]*//p" "$1" | head -n1
}

case_list_under() { # case_list_under <file> <parent-key> -> "- item" values, one per line
  awk -v key="^${2}:" '
    $0 ~ key { grab=1; next }
    grab && /^[a-zA-Z_][a-zA-Z0-9_]*:/ { grab=0 }
    grab && /^[[:space:]]*-/ { sub(/^[[:space:]]*-[[:space:]]*/, ""); print }
  ' "$1"
}

case_nested_field() { # case_nested_field <file> <parent-key> <key> -> scalar under a nested block
  awk -v parent="^${2}:" -v key="^[[:space:]]+${3}:" '
    $0 ~ parent { grab=1; next }
    grab && $0 ~ /^[a-zA-Z_][a-zA-Z0-9_]*:/ { grab=0 }
    grab && $0 ~ key { sub(key "[[:space:]]*", ""); print; exit }
  ' "$1"
}

case_nested_list() { # case_nested_list <file> <parent-key> <list-key> -> list items under a nested block
  awk -v parent="^${2}:" -v listkey="^[[:space:]]+${3}:" '
    $0 ~ parent { grab=1; next }
    grab && $0 ~ /^[a-zA-Z_][a-zA-Z0-9_]*:/ { grab=0 }
    grab && $0 ~ listkey { inlist=1; next }
    grab && inlist && /^[[:space:]]+-/ { line=$0; sub(/^[[:space:]]+-[[:space:]]*/, "", line); print line; next }
    grab && inlist && /^[[:space:]]+[a-zA-Z_]/ { inlist=0 }
  ' "$1" | sed -e "s/^'//" -e "s/'$//" -e 's/^"//' -e 's/"$//'
}

# --- list ----------------------------------------------------------------------------
cmd_list() {
  local category="${1:-}"
  local dir="$ROOT_DIR/evals/cases"
  [[ -n "$category" ]] && dir="$dir/$category"
  [[ -d "$dir" ]] || { echo "No such category: $category" >&2; exit 2; }
  find "$dir" -type f -name '*.yml' | sort
}

# --- grade ---------------------------------------------------------------------------
cmd_grade() {
  local case_file="$1" diff_file="${2:-}"
  [[ -f "$case_file" ]] || { echo "No such case file: $case_file" >&2; exit 2; }

  local id mode
  id="$(case_field "$case_file" id)"
  mode="$(case_nested_field "$case_file" checks mode)"

  local diff
  if [[ -n "$diff_file" ]]; then
    [[ -f "$diff_file" ]] || { echo "No such diff file: $diff_file" >&2; exit 2; }
    diff="$(cat "$diff_file")"
  else
    diff="$(git diff HEAD 2>/dev/null || true)"
  fi

  echo "== $id =="

  if [[ "$mode" != "deterministic" ]]; then
    echo "NOT RUN: checks.mode is '${mode:-<none>}', not 'deterministic' - grade this case with an LLM judge or a human reviewer against its expected/forbidden text."
    return 0
  fi

  local status=0 pattern

  while IFS= read -r pattern; do
    [[ -n "$pattern" ]] || continue
    if grep -E -q -- "$pattern" <<<"$diff"; then
      echo "FAIL: forbidden pattern matched: $pattern"
      status=1
    fi
  done < <(case_nested_list "$case_file" checks forbidden_patterns)

  while IFS= read -r pattern; do
    [[ -n "$pattern" ]] || continue
    if ! grep -E -q -- "$pattern" <<<"$diff"; then
      echo "FAIL: required pattern not found: $pattern"
      status=1
    fi
  done < <(case_nested_list "$case_file" checks required_patterns)

  local max_files
  max_files="$(case_nested_field "$case_file" budget max_files_changed)"
  if [[ -n "$max_files" ]]; then
    local changed
    changed="$(grep -c '^diff --git' <<<"$diff" || true)"
    if (( changed > max_files )); then
      echo "FAIL: budget exceeded: $changed files changed, max is $max_files"
      status=1
    fi
  fi

  if [[ $status -eq 0 ]]; then
    echo "PASS: no forbidden/required/budget check failed (expected/forbidden prose still needs a judge - see README)"
  fi
  return "$status"
}

# --- run -------------------------------------------------------------------------------
cmd_run() {
  local case_file="$1"
  [[ -f "$case_file" ]] || { echo "No such case file: $case_file" >&2; exit 2; }
  [[ -n "${AGENT_RUN_CMD:-}" ]] || {
    echo "AGENT_RUN_CMD is not set - this script has no agent to run. See --help." >&2
    exit 2
  }

  local task workdir
  task="$(case_field "$case_file" task)"
  workdir="$(mktemp -d)"
  trap 'rm -rf "$workdir"' EXIT

  bash -lc "$AGENT_RUN_CMD" -- "$case_file" "$task" "$workdir"

  local diff
  diff="$(git -C "$workdir" diff HEAD 2>/dev/null || true)"
  if [[ -z "$diff" ]]; then
    echo "AGENT_RUN_CMD produced no diff in $workdir (git diff HEAD was empty) - nothing to grade." >&2
    exit 2
  fi

  local tmp_diff
  tmp_diff="$(mktemp)"
  printf '%s\n' "$diff" > "$tmp_diff"
  cmd_grade "$case_file" "$tmp_diff"
  local status=$?
  rm -f "$tmp_diff"
  return "$status"
}

# --- dispatch ----------------------------------------------------------------------
mode="${1:-}"
case "$mode" in
  list) shift; cmd_list "$@" ;;
  grade) shift; [[ $# -ge 1 ]] || { usage; exit 2; }; cmd_grade "$@" ;;
  run) shift; [[ $# -ge 1 ]] || { usage; exit 2; }; cmd_run "$@" ;;
  -h|--help|"") usage; [[ "$mode" == "-h" || "$mode" == "--help" ]] && exit 0 || exit 1 ;;
  *) usage; exit 2 ;;
esac
