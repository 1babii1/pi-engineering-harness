# Notes on this run (read before citing any number)

Claude Code 2.1.270, model `haiku` (claude-haiku-4-5), 22 deterministic cases x 2 variants x 3 trials, no
errored runs. Reported cost is Claude Code's API-equivalent estimate; it was paid from a subscription quota.

## What the numbers say

- bare 24/66 (36%), harness 28/66 (42%): +6 points, z = 0.71. **Not significant**, and runs within a case are
  not independent. Harness better in 7 cases, worse in 6, equal in 9. Single-case swings of 1 in 3 are noise.
- The larger swings (verification-not-run-is-not-pass 0/3 -> 3/3, auth-external-link-two-factor 0/3 -> 2/3,
  architecture-premature-distribution 0/3 -> 2/3, and database-migration-rename-column 2/3 -> 0/3 the other way)
  are worth a repeat with more trials; with n = 3 they prove nothing.
- Cost: harness +21% (reported), input tokens 16.2k vs 13.1k per run.

## The important finding: the harness variant barely used the harness

60 of 66 harness runs finished in a single turn, i.e. the agent opened no file. It saw only `AGENTS.md`, which
loads automatically. Only the two cases that ask for code (backend-parameterized-query, frontend-server-state)
triggered file reads. So this run compares `AGENTS.md` with nothing. It does not measure the laws, skills and
proof obligations, which the harness loads on demand, and on design questions this model does not go and read them.

Consequences, not yet tested: (1) on-demand loading may simply not trigger for a small model on prose questions;
(2) with Claude's native skill discovery the result could differ, but the runner disables skills so the user's own
skills cannot leak into `bare`; (3) a variant that names the relevant skill (or preloads it) would separate "the
content helps" from "the model does not load it".

## Grader caveats

- Regex heuristics over prose; prose criteria are NOT GRADED. The graders were widened after auditing the first
  (Sonnet, 1 trial) run, hunting false negatives only, so pass rates may be slightly optimistic.
- Several cases fail in both variants for a real reason (the answer omits the point): auth-key-rotation-retention,
  auth-keys-at-rest, operations-consumer-readiness, jobs-multi-instance-rotation.
- The answers are kept locally under `responses/` (git-ignored); `bench.py --regrade <dir>` re-scores them with
  no model call.
