#!/usr/bin/env bash
set -euo pipefail

if [[ -f "${FRONTEND_VERIFY_CMD_FILE:-.pi/project/commands.env}" ]]; then
  source "${FRONTEND_VERIFY_CMD_FILE:-.pi/project/commands.env}"
fi

if [[ -n "${FRONTEND_VERIFY_CMD:-}" ]]; then
  bash -lc "$FRONTEND_VERIFY_CMD"
elif [[ -f package.json ]] && command -v npm >/dev/null 2>&1; then
  node - <<'NODE'
const p=require('./package.json').scripts||{};
for (const k of ['typecheck','lint','test','build']) if (p[k]) console.log(k)
NODE
  mapfile -t scripts < <(node -e "const p=require('./package.json').scripts||{}; for (const k of ['typecheck','lint','test','build']) if (p[k]) console.log(k)")
  [[ ${#scripts[@]} -gt 0 ]] || { echo "No frontend verification scripts found." >&2; exit 2; }
  for s in "${scripts[@]}"; do npm run "$s"; done
else
  echo "No deterministic frontend verification command configured." >&2
  exit 2
fi
