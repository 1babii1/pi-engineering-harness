# Engineering Lifecycle

IDEA
-> REQUIREMENTS
-> FOUNDATIONS
-> DOMAIN / INVARIANTS
-> SYSTEM DESIGN
-> ARCHITECTURE
-> API / DATA / SECURITY
-> IMPLEMENTATION
-> VERIFICATION
-> DELIVERY
-> PRODUCTION READINESS
-> OBSERVABILITY / OPERATIONS
-> INCIDENT
-> LEARNING

Use this as a routing map, not as an instruction to load every skill.

## Requirements
Clarify problem, acceptance criteria, assumptions, scale, latency, availability,
consistency, security, RPO/RTO when relevant, and important failure behavior.

## Design
Prefer local invariants, explicit ownership, reversible decisions, and the simplest
architecture satisfying current constraints.

## Build
Follow project conventions and canonical examples. Preserve contracts and boundaries.

## Verify
Turn material design decisions into proof obligations. Match each important claim
with evidence that can actually prove it.

## Ship
Prefer identifiable, bounded, observable, reversible change where practical.

## Run
Require operational ownership, user-relevant health signals, dependency understanding,
capacity headroom, recovery paths, and actionable alerts.

## Learn
Incident/repeated mistake -> local fix/regression -> guardrail candidate -> detector
when mechanical -> eval -> core law only when evidence supports broad generalization.
