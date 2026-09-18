# Harness Evals

Evals measure whether harness changes improve behavior enough to justify their complexity.

## Principles
- Keep model, repository fixture, and task fixed when comparing harness versions.
- Prefer deterministic graders: tests, static analysis, AST/text checks, diff checks.
- Use LLM judging only for qualities that cannot be checked deterministically.
- Run multiple trials for benchmark claims.
- Compare against a baseline such as bare Pi or core `AGENTS.md` only.
- Track correctness together with token/tool/time cost.

## What's actually automated here

`eval.sh` runs two things for real:

- **`./eval.sh grade <case-file> [diff-file]`** — checks a produced diff against a case's
  `checks:` block: `forbidden_patterns` (fail if matched), `required_patterns` (fail if
  missing), and `budget.max_files_changed`. Only cases with `checks.mode: deterministic`
  run these; cases marked `checks.mode: llm-judge` report `NOT RUN` on purpose rather than
  a fake PASS — most of a case's `expected`/`forbidden` prose describes intent ("preserves
  architecture", "loading and error states are handled"), which a regex cannot reliably
  check without false positives/negatives outweighing real catches. Grade those against the
  prose with an LLM judge or a human reviewer instead.
- **`./eval.sh run <case-file>`** — invokes `$AGENT_RUN_CMD` (required, not shipped) with
  the case's task, captures the diff it produces, and grades it the same way. This is the
  same override pattern `scripts/verify-backend.sh` already uses for
  `BACKEND_VERIFY_CMD` — this repo doesn't bundle a way to actually drive Pi/Codex/Claude/
  Cursor programmatically, so wiring one agent's CLI (or your own harness around it) into
  `AGENT_RUN_CMD` is what makes `run` do something.

`./eval.sh list [category]` just enumerates case files — unchanged from before.

## Levels

These describe how you *use* `grade`/`run`, not separate subcommands:

- **smoke** — `grade` (or `run`, with `AGENT_RUN_CMD` set) every current case once. Fast,
  representative, catches an obviously broken harness change.
- **regression** — `run` a specific case that previously reproduced a known mistake, to
  confirm a rule change actually prevents it going forward.
- **benchmark** — `run` the same case N times against two harness variants (with
  `AGENT_RUN_CMD` pointed at each variant's installed skills/rules in turn) and compare
  pass rates, token/tool/time cost — never a single run. Don't claim a benchmark result from
  one trial.

## Adding a case

Every case needs `id`, `category`, `task`, `expected`, `forbidden` (human/LLM-judge-facing
prose — keep these even when `checks:` covers part of the same ground). Add `checks:` only
for what's genuinely regex-checkable:

```yaml
checks:
  mode: deterministic        # or: llm-judge, if nothing below is reliably checkable
  forbidden_patterns:
    - 'some\.regex'
  required_patterns:
    - 'another\.regex'
```

`budget.max_files_changed` (top-level, not under `checks:`) is graded automatically
whenever it's present, regardless of `checks.mode`.
