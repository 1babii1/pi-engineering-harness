#!/usr/bin/env bash
# Runs the harness's own deterministic checks.
#
#   eval.sh smoke                     structure + eval-case lint + grader self-test (seconds)
#   eval.sh regression                smoke + the installer and verify.sh behaviour test suites
#   eval.sh grade <case-id> <file>    grade an agent response/diff against one eval case
#   eval.sh benchmark                 NOT RUN: needs an agent runtime (see evals/README.md)
#
# Exit: 0 all passed, 1 a check failed, 2 not runnable here (never reported as a pass).
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
export PYTHONDONTWRITEBYTECODE=1
cd "$ROOT_DIR"
mode="${1:-smoke}"

command -v python3 >/dev/null 2>&1 || { echo "python3 is required for the eval tooling." >&2; exit 2; }

status=0
step() { # step <label> <cmd...>
  local label="$1"; shift
  echo "==> $label"
  if "$@"; then :; else status=1; fi
}

case "$mode" in
  smoke)
    step "structure" python3 evals/run.py structure
    step "eval cases" python3 evals/run.py lint
    step "grader self-test" python3 evals/run.py selftest
    ;;
  regression)
    step "structure" python3 evals/run.py structure
    step "eval cases" python3 evals/run.py lint
    step "grader self-test" python3 evals/run.py selftest
    step "eval tooling tests" tests/eval.test.sh
    step "installer tests" tests/install.test.sh
    step "verify script tests" tests/verify.test.sh
    step "secrets guard hook tests" tests/hook-guard-secrets.test.sh
    step "stop hook tests" tests/hook-verify-on-stop.test.sh
    ;;
  grade)
    [[ $# -eq 3 ]] || { echo "Usage: $0 grade <case-id> <response-file>" >&2; exit 2; }
    exec python3 evals/run.py grade "$2" "$3"
    ;;
  benchmark)
    echo "NOT RUN: benchmark compares harness variants by running an agent on fixed tasks, which needs" >&2
    echo "an agent runtime this repository does not ship. Collect responses per case with your runtime," >&2
    echo "then score them with: $0 grade <case-id> <response-file>. See evals/README.md." >&2
    exit 2
    ;;
  *)
    echo "Usage: $0 [smoke|regression|benchmark|grade <case-id> <file>]" >&2
    exit 2
    ;;
esac
exit "$status"
