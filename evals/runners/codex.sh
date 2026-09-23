#!/usr/bin/env bash
# Benchmark runner for OpenAI Codex CLI (`codex exec`). Same contract as claude.sh.
#
# Isolation is PARTIAL and reported as such: Codex loads the user's ~/.codex/AGENTS.md, skills and hooks
# in every run, and moving CODEX_HOME would drop auth.json (a credential file this harness never copies).
# So `bare` here means "no project harness", not "no instructions at all", and the same user context
# affects both variants. Treat Codex numbers as indicative, not as a controlled baseline.
#   -s read-only        nothing is edited; cases are answered in prose
#   --ephemeral         no session files
#   --skip-git-repo-check  the scratch project is a fresh directory
set -euo pipefail

CODEX_BIN="${CODEX_BIN:-codex}"
command -v "$CODEX_BIN" >/dev/null 2>&1 || { echo "codex CLI not found (set CODEX_BIN)" >&2; exit 2; }

if [[ "${1:-}" == "info" ]]; then
  ver="$("$CODEX_BIN" --version 2>/dev/null | head -n1)"
  printf '{"agent":"codex","version":"%s","isolation":"partial (user-level AGENTS.md, skills and hooks still loaded in both variants)"}\n' "$ver"
  exit 0
fi

workdir="$1"; task_file="$2"
[[ -d "$workdir" && -f "$task_file" ]] || { echo "usage: $0 <workdir> <task-file> | info" >&2; exit 2; }

out="$(mktemp)"; trap 'rm -f "$out"' EXIT
args=(exec --ephemeral --skip-git-repo-check -s read-only --color never -C "$workdir" -o "$out")
[[ -z "${BENCH_MODEL:-}" ]] || args+=(-m "$BENCH_MODEL")

start=$(date +%s%3N)
"$CODEX_BIN" "${args[@]}" "$(cat "$task_file")" </dev/null >/dev/null 2>&1
end=$(date +%s%3N)

if [[ -n "${BENCH_META_FILE:-}" ]]; then
  printf '{"model":"%s","cost_usd":null,"duration_ms":%s}\n' "${BENCH_MODEL:-default}" "$((end - start))" > "$BENCH_META_FILE"
fi
cat "$out"
