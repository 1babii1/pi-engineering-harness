# Harness Evals

Evals measure whether harness changes improve behavior enough to justify their complexity.

## Principles
- Keep model, repository fixture, and task fixed when comparing harness versions.
- Prefer deterministic graders: tests, static analysis, AST/text checks, diff checks.
- Use LLM judging only for qualities that cannot be checked deterministically.
- Run multiple trials for benchmark claims.
- Compare against a baseline such as bare Pi or core `AGENTS.md` only.
- Track correctness together with token/tool/time cost.

## Case format (`evals/cases/<category>/<name>.yml`)

```yaml
id: <category>-<name>          # unique; must start with the folder name
category: auth
task: 'What the agent is asked to do'   # quote it if it contains ": "
expected:                      # prose criteria (human / LLM judge); reported as NOT GRADED
  - ...
forbidden:
  - ...
must_match:                    # deterministic: every regex must match the response (Python re,
  - '(?i)email_verified'       #   MULTILINE; put (?i) / (?s) first)
must_not_match:                # deterministic: none may match
  - '(?i)\.Result\b'
checks:
  mode: mixed                  # deterministic | mixed
```

Every case needs at least one deterministic grader. These are heuristics over text: they check
that key concepts are present and clearly forbidden recommendations are absent. They complement,
never replace, the prose criteria.

## Fixtures

`evals/fixtures/<id>.good.md` and `<id>.bad.md` are a response that should pass and one that should
fail. `./eval.sh smoke` fails if a grader rejects the good one or accepts the bad one, so a vacuous
or over-strict grader cannot ship. Write graders against natural phrasings, not one exact sentence:
the self-test exists because the first drafts of several graders rejected their own good example.

## Levels
- smoke - structure, case lint, grader self-test (no agent needed).
- regression - smoke plus the shell test suites in `tests/` (known mistakes the rules must prevent).
- benchmark - repeated comparison between harness variants with a real agent (`evals/bench.py`, below).
  It calls a model, so it costs money and is never part of `./eval.sh regression`.

## Benchmark: bare vs harness with a real agent

```bash
python3 evals/bench.py --agent claude --dry-run                      # plan and run count, calls nothing
python3 evals/bench.py --agent claude --trials 5 --max-cost-usd 15   # every deterministic case, both variants
python3 evals/bench.py --agent claude --category concurrency --trials 3
```

Per (case, trial, variant) it builds a fresh scratch project - `bare`: empty; `harness`: `install.sh --agent
<agent> <profile>` - runs the case task through `evals/runners/<agent>.sh`, and grades the answer with the same
`must_match` / `must_not_match` graders as `./eval.sh grade`. Variants alternate within each case and trial so
drift hits both alike. Output: `report.md`, `results.json`, and every answer under `responses/`.

Runner contract (one small script per agent): `runner.sh info` prints a JSON line (agent, version, isolation);
`runner.sh <workdir> <task-file>` prints the final answer on stdout and may write cost/tokens to
`$BENCH_META_FILE`. Non-zero exit is an error, never a pass.

| runner | isolation |
|---|---|
| `claude.sh` | full: `--setting-sources project,local`, skills disabled, read-only tools. Verified: a fresh session reports no user instructions, memory or skills. |
| `codex.sh` | partial: Codex always loads the user's `~/.codex/AGENTS.md`, skills and hooks, and moving `CODEX_HOME` would drop `auth.json`. `bare` means "no project harness", not "no instructions". Indicative only. |
| `pi.sh` | none bundled: Pi's headless CLI was not available to verify, so set `PI_RUN_CMD` yourself (see the script header). |

How to read a result:

- The graders are regex heuristics over prose. A pass means the answer has the key concepts and none of the
  forbidden recommendations, not that it is good; prose criteria stay NOT GRADED. Before trusting a
  difference, read the failing responses under `responses/` and check the grader was fair - the first real run
  of this benchmark found a grader that rejected a correct answer because it wrote "caught" instead of
  "catch". Fix a grader by widening word forms and order, never by adding a new acceptable meaning, and
  re-run `./eval.sh smoke` so its fixtures still discriminate.
- Both variants get the same task preamble (no code exists, do not ask for it, answer concretely). Without it
  the harness rule "do not invent APIs" makes that variant ask questions more often, a confound.
- Skills are disabled in the Claude runner so the user's own skills cannot leak into `bare`; the harness
  variant reaches `.pi/skills/*` by reading them, as `AGENTS.md` tells any agent to. This measures the
  harness text, not Claude's native skill matching.
- Errored runs (timeout, CLI failure, budget) are reported separately, never as pass or fail.
- Small trial counts prove nothing. Do not claim an improvement from fewer than ~5 trials per case and
  variant, and never across agents. Compare the harness variant's cost too: it reads files, so it is usually
  slower and more expensive.
