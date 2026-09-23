---
name: frontend-audit
description: "Read-only production audit for React/TypeScript frontends: architecture, correctness, performance, accessibility, state and API usage."
---
# Frontend Audit

Audit only. Do not modify code unless explicitly asked.

## Passes
1. Architecture and boundaries.
2. React correctness.
3. State ownership.
4. Network and server-state behavior.
5. Type safety.
6. Performance and bundle risks.
7. Accessibility and UX states.
8. Security-sensitive browser behavior.
9. Test coverage of important flows.

## React
- Inspect every non-trivial `useEffect`: identify the external system it synchronizes with.
- Flag derived state stored unnecessarily.
- Look for stale closures, unstable dependencies, incorrect keys and duplicated state.
- Do not recommend memoization without a measured or credible rendering cost.

## State
- Server state belongs in TanStack Query.
- Shared client-only state may belong in Zustand.
- Local UI state should stay local when practical.
- Flag unnecessary Query -> effect -> Zustand synchronization.

## Performance
Look for:
- request waterfalls;
- large eager imports;
- unnecessary client work;
- avoidable rerenders;
- oversized assets;
- missing lazy loading where it materially helps.

## Accessibility
Check semantic HTML, labels, focus, keyboard access, error messages, loading states and empty states.

## Findings
For each finding include severity, confidence, evidence, impact and minimal recommendation.
Do not report preferences as defects.
