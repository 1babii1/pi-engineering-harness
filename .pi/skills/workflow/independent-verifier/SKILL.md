---
name: independent-verifier
description: Use for high-risk work: auth, credentials, payments, migrations, concurrency, public contracts, distributed coordination, production infrastructure, destructive operations (see .pi/laws/signals.md "High risk").
---
# Independent Verifier

Review with fresh context after implementation. Do not continue the builder's reasoning.

Inputs should be limited to:
- scope contract
- final diff
- relevant project context/canonical examples
- verification results
- high-risk requirements

Check:
1. Does the diff satisfy the scope contract?
2. Are compatibility and security properties preserved?
3. Is the verification evidence sufficient?
4. Are failure modes, rollback/migration concerns, and concurrency/data consistency handled where applicable?
5. Did the solution introduce unnecessary complexity or unrelated changes?

Output only evidence-backed blockers/high/medium findings and unresolved verification gaps.
Do not redesign the feature unless the implementation has a concrete defect.

## How to run it
Fresh context means no builder reasoning, only artifacts. In Claude Code launch a new subagent (or a
new session); in other agents open a new thread. Give it the inputs above and the list of proof
obligations from `.pi/work/obligations.md` if one exists. Do not pass the builder's summary of why the
change is correct.

## Do not trust, re-check
- Re-run the key evidence yourself (the tests, the build) instead of reading that they passed.
- For a critical test, break the guarded behavior in a scratch copy and confirm that specific test
  fails; a test that stays green proves nothing. Restore afterwards.
- For each proof obligation write: obligation -> evidence actually seen -> satisfied / not satisfied /
  unverified.

## Output
Findings ranked BLOCKER / HIGH / MEDIUM, each with the evidence and the smallest fix; then the
obligation table; then what remains unverified. "No findings" is acceptable only together with the list
of what was checked and how.
