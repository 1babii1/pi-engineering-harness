# Benchmark 2026-09-23 - claude

- agent: claude 2.1.270 (Claude Code)
- isolation: full (setting-sources project,local; skills disabled; read-only tools)
- model: haiku
- harness: 4.9.0, profile `fullstack production`
- trials per case and variant: 3
- task preamble (both variants): This is a design/engineering question. There is no application code to inspect, so do not ask for code or clarification: give your concrete recommendation, the key trade-offs, and any assumptions you make. Where concrete code or a query is the clearest answer, include a short snippet.
- graders: deterministic regex heuristics only (`must_match` / `must_not_match`); prose criteria NOT GRADED
- a pass rate is passed/graded runs; errored runs are shown separately and never counted as pass or fail

| case | bare | harness |
|---|---|---|
| architecture-async-notification | 1/3 | 0/3 |
| architecture-cache-obligations | 1/3 | 0/3 |
| architecture-local-invariant | 2/3 | 2/3 |
| architecture-premature-distribution | 0/3 | 2/3 |
| auth-external-link-two-factor | 0/3 | 2/3 |
| auth-external-link-unconfirmed | 0/3 | 0/3 |
| auth-key-rotation-retention | 0/3 | 0/3 |
| auth-keys-at-rest | 0/3 | 0/3 |
| auth-password-change-sessions | 0/3 | 1/3 |
| backend-parameterized-query | 3/3 | 2/3 |
| boundary-webhook-payment-notification | 0/3 | 0/3 |
| concurrency-check-then-act | 3/3 | 3/3 |
| database-migration-rename-column | 2/3 | 0/3 |
| destructive-bulk-delete-department | 2/3 | 2/3 |
| frontend-server-client-boundary | 2/3 | 3/3 |
| frontend-server-state | 0/3 | 1/3 |
| jobs-multi-instance-rotation | 0/3 | 0/3 |
| operations-consumer-readiness | 0/3 | 0/3 |
| performance-index-verify-after | 3/3 | 2/3 |
| testing-regression-test-evidence | 3/3 | 2/3 |
| verification-migration-evidence | 2/3 | 3/3 |
| verification-not-run-is-not-pass | 0/3 | 3/3 |
| **all** | **24/66** | **28/66** |

single-turn runs (the agent read no file): bare 57/66, harness 60/66

> WARNING: most harness runs never opened a harness file, so the harness variant mostly saw only the
> always-loaded AGENTS.md. This compares AGENTS.md with nothing; it does not measure the laws, skills
> and proof obligations that are meant to be loaded on demand.

cost (USD, as reported by the agent): bare 1.15, harness 1.39
