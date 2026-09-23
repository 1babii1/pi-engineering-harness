#!/usr/bin/env bash
# Benchmark runner for Claude Code (headless `claude -p`).
#
# Contract (shared by every runner in this directory):
#   runner.sh info                        -> one line of JSON describing the agent (name, version, isolation)
#   runner.sh <workdir> <task-file>       -> final answer on stdout; if $BENCH_META_FILE is set, one JSON
#                                            object (model, cost_usd, tokens, duration_ms, turns) is written there.
#                                            Non-zero exit = the run failed (never graded as a pass).
#
# Isolation, so the `bare` variant really is bare and both variants see the same user-level context:
#   --setting-sources project,local   ignores the user's ~/.claude settings, hooks and user CLAUDE.md
#   --disable-slash-commands          no skills at all (the user's own skills would leak into `bare`); the
#                                     harness variant still reaches .pi/skills/* by reading them, which is how
#                                     AGENTS.md tells any agent to use them
#   --strict-mcp-config               no MCP servers
#   --tools Read,Grep,Glob            read-only; cases are answered in prose, nothing is edited
# `--bare` would be simpler but needs ANTHROPIC_API_KEY (it never reads OAuth), and this harness never
# handles credentials. Verified: with these flags a fresh session reports no instructions/skills loaded.
set -euo pipefail

CLAUDE_BIN="${CLAUDE_BIN:-claude}"
if ! command -v "$CLAUDE_BIN" >/dev/null 2>&1 && [[ -x "$HOME/.local/bin/claude" ]]; then
  CLAUDE_BIN="$HOME/.local/bin/claude"
fi
command -v "$CLAUDE_BIN" >/dev/null 2>&1 || { echo "claude CLI not found (set CLAUDE_BIN)" >&2; exit 2; }

if [[ "${1:-}" == "info" ]]; then
  ver="$("$CLAUDE_BIN" --version 2>/dev/null | head -n1)"
  printf '{"agent":"claude","version":"%s","isolation":"full (setting-sources project,local; skills disabled; read-only tools)"}\n' "$ver"
  exit 0
fi

workdir="$1"; task_file="$2"
[[ -d "$workdir" && -f "$task_file" ]] || { echo "usage: $0 <workdir> <task-file> | info" >&2; exit 2; }

raw="$(mktemp)"; trap 'rm -f "$raw"' EXIT
args=(-p "$(cat "$task_file")"
  --setting-sources project,local
  --disable-slash-commands
  --strict-mcp-config
  --tools "Read,Grep,Glob"
  --allowedTools "Read Grep Glob"
  --permission-mode dontAsk
  --output-format json
  --no-session-persistence
  --max-budget-usd "${BENCH_MAX_USD_PER_RUN:-1}")
[[ -z "${BENCH_MODEL:-}" ]] || args+=(--model "$BENCH_MODEL")

( cd "$workdir" && "$CLAUDE_BIN" "${args[@]}" </dev/null ) >"$raw"

python3 - "$raw" <<'PY'
import json, os, sys
d = json.load(open(sys.argv[1]))
if d.get("is_error"):
    print(f"claude reported an error: {d.get('subtype')} {str(d.get('result'))[:200]}", file=sys.stderr)
    sys.exit(1)
usage = d.get("usage") or {}
meta = {
    "model": ",".join(sorted((d.get("modelUsage") or {}).keys())),
    "cost_usd": d.get("total_cost_usd"),
    "input_tokens": (usage.get("input_tokens") or 0) + (usage.get("cache_creation_input_tokens") or 0)
    + (usage.get("cache_read_input_tokens") or 0),
    "output_tokens": usage.get("output_tokens"),
    "duration_ms": d.get("duration_ms"),
    "turns": d.get("num_turns"),
}
if os.environ.get("BENCH_META_FILE"):
    json.dump(meta, open(os.environ["BENCH_META_FILE"], "w"))
sys.stdout.write(d.get("result") or "")
PY
