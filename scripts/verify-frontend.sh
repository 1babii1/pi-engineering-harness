#!/usr/bin/env bash
# verify-frontend.sh [dir ...]
# Runs the package.json verification scripts (typecheck, lint, test, and build unless the level is
# `quick`) in the given directories (default: .). The package manager follows the lockfile
# (pnpm / yarn / npm). A repository-owned FRONTEND_VERIFY_CMD in .pi/project/commands.sh (or the
# file named by FRONTEND_VERIFY_CMD_FILE) wins and runs once from the repository root.
# Exit: 0 pass, 1 fail, 2 not configured / tooling or dependencies missing.
set -euo pipefail

ENV_FILE="${FRONTEND_VERIFY_CMD_FILE:-.pi/project/commands.sh}"
if [[ -f "$ENV_FILE" ]]; then
  # shellcheck disable=SC1090
  source "$ENV_FILE"
fi

if [[ -n "${FRONTEND_VERIFY_CMD:-}" ]]; then
  # The command ran, so any non-zero exit is a real failure, never "not configured" (exit 2).
  bash -c "$FRONTEND_VERIFY_CMD" || exit 1
  exit 0
fi

command -v node >/dev/null 2>&1 || { echo "node is not installed; cannot verify the frontend." >&2; exit 2; }

wanted="typecheck lint test"
[[ "${VERIFY_LEVEL:-quick}" == quick ]] || wanted="$wanted build"

dirs=("$@")
[[ ${#dirs[@]} -gt 0 ]] || dirs=(.)

status=0
for d in "${dirs[@]}"; do
  if [[ ! -f "$d/package.json" ]]; then
    echo "No package.json in '$d'." >&2; [[ $status -eq 1 ]] || status=2; continue
  fi
  pm=npm
  [[ -f "$d/pnpm-lock.yaml" ]] && pm=pnpm
  [[ -f "$d/yarn.lock" ]] && pm=yarn
  command -v "$pm" >/dev/null 2>&1 || { echo "$pm is not installed; cannot verify '$d'." >&2; [[ $status -eq 1 ]] || status=2; continue; }
  if [[ ! -d "$d/node_modules" ]]; then
    echo "Dependencies are not installed in '$d' (no node_modules); run '$pm install' first." >&2
    [[ $status -eq 1 ]] || status=2; continue
  fi

  mapfile -t scripts < <(cd "$d" && WANTED="$wanted" node -e '
    const s = require("./package.json").scripts || {};
    for (const k of process.env.WANTED.split(" ")) if (s[k]) console.log(k);')
  if [[ ${#scripts[@]} -eq 0 ]]; then
    echo "No verification scripts (${wanted// /, }) in '$d/package.json'." >&2
    [[ $status -eq 1 ]] || status=2; continue
  fi
  for s in "${scripts[@]}"; do
    echo "-- $pm run $s ($d)"
    # CI=true keeps watch-mode test runners (vitest, jest) from hanging.
    if (cd "$d" && CI=true "$pm" run "$s"); then :; else status=1; fi
  done
done
exit "$status"
