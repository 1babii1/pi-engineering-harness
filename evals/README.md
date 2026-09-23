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
- benchmark - repeated comparison between harness variants with a real agent runtime. Not runnable
  from this repository; collect responses per case, then score with `./eval.sh grade`.
