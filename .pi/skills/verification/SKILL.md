---
name: verification
description: Use after implementation and before claiming completion. Select the smallest deterministic verification that covers the change.
---
# Verification

Verification is evidence, not confidence.

## Strategy
Use progressive verification:
1. targeted checks for the changed area;
2. broader checks when shared contracts or core code changed;
3. full checks only for high-risk or release-level work.

Prefer repository commands recorded in `.pi/project/commands.md`.

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
