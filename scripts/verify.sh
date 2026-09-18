#!/usr/bin/env bash
set -euo pipefail

LEVEL="${1:-quick}"
case "$LEVEL" in quick|standard|full) ;; *) echo "Usage: $0 [quick|standard|full]" >&2; exit 2;; esac

changed="$(git diff --name-only HEAD 2>/dev/null || true; git diff --name-only --cached 2>/dev/null || true)"
[[ -n "$changed" ]] || changed="$(git ls-files 2>/dev/null || true)"

backend=0; frontend=0; k8s=0
if grep -Eiq '\.(cs|csproj|sln)$|(^|/)(backend|src/[^/]*(api|application|domain|infrastructure))/' <<<"$changed"; then backend=1; fi
if grep -Eiq '\.(ts|tsx|js|jsx|css|scss)$|(^|/)(frontend|web|client)/|package\.json$' <<<"$changed"; then frontend=1; fi
if grep -Eiq '(^|/)(k8s|kubernetes|helm|charts)/|\.ya?ml$' <<<"$changed"; then k8s=1; fi

status=0
run() { echo "==> $*"; "$@" || status=$?; }
[[ $backend -eq 1 ]] && run "$(dirname "$0")/verify-backend.sh"
[[ $frontend -eq 1 ]] && run "$(dirname "$0")/verify-frontend.sh"
[[ $k8s -eq 1 && "$LEVEL" != quick ]] && run "$(dirname "$0")/verify-k8s.sh"

if [[ $backend -eq 0 && $frontend -eq 0 && $k8s -eq 0 ]]; then
  echo "No known project area detected. Use repository-specific verification commands."
fi
exit "$status"
