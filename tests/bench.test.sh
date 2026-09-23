#!/usr/bin/env bash
# Tests for evals/bench.py using stub runners (no model is called). A stub answers with the case's known
# good fixture when the scratch project has the harness installed (AGENTS.md present) and with the bad
# fixture when it does not, so the whole pipeline - scratch projects, harness install, grading, error
# accounting, budget stop, report - is checked deterministically.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."
# shellcheck source=tests/lib.sh
source tests/lib.sh

BENCH="python3 $ROOT_DIR/evals/bench.py"
CASES="concurrency-check-then-act,architecture-cache-obligations"

mk_runner() { # mk_runner <path> <mode: harness-aware|fail|costly>
  cat > "$1" <<EOF
#!/usr/bin/env bash
set -euo pipefail
if [[ "\${1:-}" == "info" ]]; then echo '{"agent":"stub","version":"0","isolation":"none (test)"}'; exit 0; fi
workdir="\$1"
case "$2" in
  fail) echo "stub failure" >&2; exit 1 ;;
  echo) cat "\$2"; exit 0 ;;
  costly) [[ -z "\${BENCH_META_FILE:-}" ]] || echo '{"model":"stub","cost_usd":1.0}' > "\$BENCH_META_FILE" ;;
esac
id="\$BENCH_CASE_ID"
if [[ -f "\$workdir/AGENTS.md" ]]; then cat "$ROOT_DIR/evals/fixtures/\$id.good.md"; else cat "$ROOT_DIR/evals/fixtures/\$id.bad.md"; fi
EOF
  chmod +x "$1"
}

D="$(new_dir)"

# --- plan only ---------------------------------------------------------------------------------
mk_runner "$D/ok.sh" harness-aware
out="$($BENCH --agent claude --runner "$D/ok.sh" --cases "$CASES" --trials 3 --dry-run 2>&1)"
assert_out_contains "$out" "2 cases x 2 variants x 3 trials = 12 agent runs" "dry-run reports the number of agent runs"
assert_out_contains "$out" "real model call" "dry-run warns that runs cost money"
assert_no_file "$D/results" "dry-run writes nothing"

# --- a full pipeline run -----------------------------------------------------------------------
OUT="$D/out"
out="$($BENCH --agent claude --runner "$D/ok.sh" --cases "$CASES" --trials 2 --out "$OUT" 2>&1)"
assert_file "$OUT/report.md" "a report is written"
assert_file "$OUT/results.json" "raw results are written"
assert_file "$OUT/responses/concurrency-check-then-act/harness-1.md" "each response is saved"
assert_contains "$OUT/report.md" "| concurrency-check-then-act | 0/2 | 2/2 |" "bare fails and harness passes on the stub, per case"
assert_contains "$OUT/report.md" "| **all** | **0/4** | **4/4** |" "totals aggregate across cases and trials"
assert_contains "$OUT/report.md" "isolation: none (test)" "the runner's isolation statement is in the report header"
assert_contains "$OUT/report.md" "regex heuristics" "the report states the graders are heuristics"
assert_eq "$(python3 -c "import json;print(len(json.load(open('$OUT/results.json'))['runs']))")" "8" "every run is recorded"

# --- --regrade re-scores saved answers with the current graders and calls no model ---------------
out="$($BENCH --regrade "$OUT" 2>&1)"
assert_file "$OUT/report-regraded.md" "regrade writes its own report"
assert_out_contains "$out" "0 verdict(s) changed" "regrading unchanged graders and answers changes nothing"
cp "$ROOT_DIR/evals/fixtures/concurrency-check-then-act.good.md" "$OUT/responses/concurrency-check-then-act/bare-1.md"
out="$($BENCH --regrade "$OUT" 2>&1)"
assert_out_contains "$out" "concurrency-check-then-act bare #1: fail -> pass" "regrade picks up a changed verdict and names it"
assert_contains "$OUT/results.json" '"status": "fail"' "regrade does not overwrite the original results"

# --- the preamble reaches the agent for both variants -------------------------------------------
mk_runner "$D/echo.sh" echo
OUT4="$D/out-echo"
$BENCH --agent claude --runner "$D/echo.sh" --cases concurrency-check-then-act --trials 1 --out "$OUT4" >/dev/null 2>&1
assert_contains "$OUT4/responses/concurrency-check-then-act/bare-1.md" "no application code to inspect" "the preamble is prepended for the bare variant"
assert_contains "$OUT4/responses/concurrency-check-then-act/harness-1.md" "no application code to inspect" "the preamble is prepended for the harness variant"
assert_contains "$OUT4/report.md" "task preamble (both variants)" "the report states the preamble"
assert_contains "$OUT4/responses/concurrency-check-then-act/bare-1.md" "include a short snippet" "the preamble allows code where code is the answer"

# --- errors are not passes and not fails -------------------------------------------------------
mk_runner "$D/fail.sh" fail
OUT2="$D/out-fail"
$BENCH --agent claude --runner "$D/fail.sh" --cases concurrency-check-then-act --trials 1 --out "$OUT2" >/dev/null 2>&1
assert_contains "$OUT2/report.md" "- (1 err)" "errored runs are shown as errors, not as a pass rate"
assert_eq "$(python3 -c "import json;print([r['status'] for r in json.load(open('$OUT2/results.json'))['runs']])")" "['error', 'error']" "runner failures are recorded as errors"

# --- budget stops the loop ---------------------------------------------------------------------
mk_runner "$D/costly.sh" costly
OUT3="$D/out-cost"
err="$($BENCH --agent claude --runner "$D/costly.sh" --cases "$CASES" --trials 2 --max-cost-usd 1 --out "$OUT3" 2>&1 >/dev/null)"
assert_out_contains "$err" "reached --max-cost-usd" "the budget stop is announced"
assert_eq "$(python3 -c "import json;print(len(json.load(open('$OUT3/results.json'))['runs']))")" "1" "no run starts after the budget is reached"

# --- argument validation -----------------------------------------------------------------------
rc=0; $BENCH --agent claude --runner "$D/ok.sh" --variants nope --dry-run >/dev/null 2>&1 || rc=$?
assert_eq "$rc" "2" "an unknown variant is rejected"
rc=0; $BENCH --agent claude --runner "$D/ok.sh" --cases does-not-exist --dry-run >/dev/null 2>&1 || rc=$?
assert_eq "$rc" "1" "an unknown case id is rejected"
rc=0; $BENCH --agent claude --runner "$D/missing.sh" --dry-run >/dev/null 2>&1 || rc=$?
assert_eq "$rc" "2" "a missing runner is rejected"

# --- runners honour the contract ---------------------------------------------------------------
for r in claude codex pi; do
  rc=0; info="$("$ROOT_DIR/evals/runners/$r.sh" info 2>/dev/null)" || rc=$?
  if [[ "$r" == "pi" || "$rc" == "0" ]]; then
    assert_out_contains "$info" "\"agent\":\"$r\"" "$r runner 'info' prints agent JSON"
  else
    ok "$r runner 'info' skipped ($r CLI not installed here)"
  fi
done
rc=0; PI_RUN_CMD= "$ROOT_DIR/evals/runners/pi.sh" "$D" "$D/ok.sh" >/dev/null 2>&1 || rc=$?
assert_eq "$rc" "2" "the pi runner refuses to guess an invocation when PI_RUN_CMD is unset"

finish
