#!/usr/bin/env bash
# Benchmark runner for Pi. Same contract as claude.sh.
#
# Pi's headless CLI is not bundled or verified by this repository (it was not installed where this runner
# was written), so nothing about its flags is guessed here. Provide the invocation yourself:
#
#   PI_RUN_CMD='pi --your-headless-flags "$(cat "$2")"'   # $1 = workdir, $2 = task file
#
# It is run as `bash -c "$PI_RUN_CMD" -- <workdir> <task-file>` from inside <workdir> and must print the
# final answer on stdout. Report isolation honestly in PI_ISOLATION (default: unknown).
set -euo pipefail

if [[ "${1:-}" == "info" ]]; then
  printf '{"agent":"pi","version":"%s","isolation":"%s"}\n' "${PI_VERSION:-unknown}" "${PI_ISOLATION:-unknown}"
  exit 0
fi

[[ -n "${PI_RUN_CMD:-}" ]] || {
  echo "PI_RUN_CMD is not set: this runner does not know Pi's headless invocation. See the header of $0." >&2
  exit 2
}
workdir="$1"; task_file="$2"
[[ -d "$workdir" && -f "$task_file" ]] || { echo "usage: $0 <workdir> <task-file> | info" >&2; exit 2; }

start=$(date +%s%3N)
( cd "$workdir" && bash -c "$PI_RUN_CMD" -- "$workdir" "$task_file" </dev/null )
end=$(date +%s%3N)
if [[ -n "${BENCH_META_FILE:-}" ]]; then
  printf '{"model":"%s","cost_usd":null,"duration_ms":%s}\n' "${BENCH_MODEL:-unknown}" "$((end - start))" > "$BENCH_META_FILE"
fi
