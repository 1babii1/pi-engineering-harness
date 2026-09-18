#!/usr/bin/env bash
set -euo pipefail

if [[ -f "${BACKEND_VERIFY_CMD_FILE:-.pi/project/commands.env}" ]]; then
  # Optional project-local overrides. This file is shell code by design and must be repository-owned.
  source "${BACKEND_VERIFY_CMD_FILE:-.pi/project/commands.env}"
fi

if [[ -n "${BACKEND_VERIFY_CMD:-}" ]]; then
  bash -lc "$BACKEND_VERIFY_CMD"
elif command -v dotnet >/dev/null 2>&1 && compgen -G '*.sln' >/dev/null; then
  dotnet build
  dotnet test --no-build
else
  echo "No deterministic backend verification command configured." >&2
  exit 2
fi
