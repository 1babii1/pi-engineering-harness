# Harness Evals

Evals measure whether harness changes improve behavior enough to justify their complexity.

## Principles
- Keep model, repository fixture, and task fixed when comparing harness versions.
- Prefer deterministic graders: tests, static analysis, AST/text checks, diff checks.
- Use LLM judging only for qualities that cannot be checked deterministically.
- Run multiple trials for benchmark claims.
- Compare against a baseline such as bare Pi or core `AGENTS.md` only.
- Track correctness together with token/tool/time cost.

## Levels
- smoke — a few fast representative cases.
- regression — known mistakes that rules should prevent.
- benchmark — repeated comparison between harness variants.
