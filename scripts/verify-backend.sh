#!/usr/bin/env bash
# verify-backend.sh [dir ...]
# Builds and tests the .NET project(s) in the given directories (default: .).
# A repository-owned override wins: BACKEND_VERIFY_CMD in .pi/project/commands.sh (or the file
# named by BACKEND_VERIFY_CMD_FILE). The override runs once, from the repository root.
# Exit: 0 pass, 1 fail, 2 not configured / tooling missing.
set -euo pipefail

ENV_FILE="${BACKEND_VERIFY_CMD_FILE:-.pi/project/commands.sh}"
if [[ -f "$ENV_FILE" ]]; then
  # Optional project-local overrides. This file is shell code by design and must be repository-owned.
  # shellcheck disable=SC1090
  source "$ENV_FILE"
fi

if [[ -n "${BACKEND_VERIFY_CMD:-}" ]]; then
  # The command ran, so any non-zero exit is a real failure, never "not configured" (exit 2).
  bash -c "$BACKEND_VERIFY_CMD" || exit 1
  exit 0
fi

command -v dotnet >/dev/null 2>&1 || { echo "dotnet is not installed; cannot verify the backend." >&2; exit 2; }

dirs=("$@")
[[ ${#dirs[@]} -gt 0 ]] || dirs=(.)

status=0
for d in "${dirs[@]}"; do
  mapfile -t solutions < <(compgen -G "$d/*.slnx" || true; compgen -G "$d/*.sln" || true)
  if [[ ${#solutions[@]} -eq 0 ]]; then
    mapfile -t solutions < <(compgen -G "$d/*.csproj" || true)
  fi
  if [[ ${#solutions[@]} -ne 1 ]]; then
    echo "Cannot pick a single solution/project in '$d' (found ${#solutions[@]}). Set BACKEND_VERIFY_CMD in .pi/project/commands.sh." >&2
    [[ $status -eq 1 ]] || status=2
    continue
  fi
  target="${solutions[0]}"
  echo "-- dotnet build/test: $target"
  if dotnet build "$target" && dotnet test "$target" --no-build; then :; else status=1; fi
done
exit "$status"
