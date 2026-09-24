---
name: pi-verification
description: Use after implementation and before claiming completion. Select the smallest deterministic verification that covers the change.
---
# Verification

Verification is evidence, not confidence.

## Strategy
Use progressive verification:
1. targeted checks for the changed area;
2. broader checks when shared contracts or core code changed;
3. full checks only for high-risk or release-level work.

Prefer repository commands recorded in `.pi/project/commands.md`. When the harness scripts are
installed, `.harness/scripts/verify.sh [quick|standard|full]` detects what changed (including new
untracked files), runs the matching checks and prints PASS / FAIL / NOT RUN per area; use its report
verbatim. Override its auto-detection through `.pi/project/commands.sh`.

## Levels
### quick
- compile/typecheck relevant area
- targeted tests

### standard
- quick
- lint/static analysis
- broader affected tests
- build when relevant

### full
- standard
- integration/e2e where available
- security/infrastructure checks when applicable
- production/release checks

## Failure classification
Classify every failure as one of:
- introduced by this change
- pre-existing
- environment/tooling
- unknown

Do not fix unrelated failures unless requested.

## Completion report
Report:
- PASS / FAIL / NOT RUN for each applicable check
- exact command used
- relevant failure summary
- anything still unverified

Never say "works" or "all good" when required checks were not run.

## Claims about framework or library behavior
Do not verify a behavior claim ("the option cache is re-read", "this ordering signs new tokens")
from memory or from the shape of the code. Read the library source or docs for the installed
version, or write the smallest experiment that shows it, and keep that experiment as a test when
the behavior is load-bearing. Several defects were found only because an assumed ordering, cache
scope or default was tested instead of trusted.

## A test you have not seen fail is not evidence
For a regression or security test, break the fix (or the guard) and watch that specific test go
red, then restore it. See `coding/testing`.
