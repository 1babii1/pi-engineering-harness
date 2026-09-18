---
name: scope-control
description: Use for non-trivial changes where requirements, compatibility, or change boundaries could drift during implementation.
---
# Scope Control

Before implementation, write a short task contract using `.harness/templates/scope-contract.md` when available.

Capture only:
- Goal
- Must change
- Must preserve
- Out of scope
- Compatibility constraints
- Risks
- Verification evidence required

During implementation:
- Compare the diff to the contract.
- Do not expand scope silently.
- If a required change conflicts with "must preserve", stop and resolve the conflict explicitly.
- If the change becomes much larger than expected, reconsider the design or split into reviewable steps.

A scope contract is temporary task context, not a permanent architecture document.
