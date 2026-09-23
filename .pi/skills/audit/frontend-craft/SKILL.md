---
name: frontend-craft-audit
description: Read-only craft audit for React/TypeScript frontends - code cleanliness, idiomatic library use, render performance, and consistency. Use when the question is "is this senior-level code", not "is this correct".
---
# Frontend Craft Audit

Audit only. Do not modify code unless explicitly asked.
This is not `frontend-audit`: that one asks "is it correct, accessible and safe", this one asks "is it clean, idiomatic, fast and consistent". Do not re-report correctness or a11y bugs here.

## Three axes, never merged

Report each axis separately and end with the worst finding **per axis**.

1. **Conventions** - does this match *this* repository.
2. **Library idiom** - is each library used the way its own design intends.
3. **Craft** - structure, smells, and render performance.

## The repo always overrides

Read the repo's own standards first and treat them as binding: `.pi/project/conventions.md`, `.pi/project/canonical-examples.md`, `eslint.config.*`, `tsconfig.json` strictness, `components.json`, and the repository's existing layering (whatever it is - do not impose a layout it does not use).
A deviation from a generic React style guide is not a finding. A deviation from the repo is.

## Axis 1: Conventions

- A page that does not follow the established loading / empty / error / unauthorised ladder used by its sibling pages.
- API access that bypasses the shared client or the established proxy boundary.
- A component placed in the wrong layer for its responsibility.
- Forms built differently from the canonical form.
- Divergent naming for the same concept across feature/entity/module folders.

## Axis 2: Library idiom

Apply only the bullets for libraries this repository actually uses. Not using TanStack Query, Next, or react-hook-form is not a finding.

- **TanStack Query**: query keys as structured arrays from a key factory, not ad-hoc strings; server data read straight from the cache instead of copied into `useState`/`useEffect`; `select` for derived shapes; one stable `QueryClient`, never constructed during render; deliberate `staleTime`/`gcTime` rather than defaults by accident; invalidation on mutation success instead of manual cache surgery; dependent queries examined for waterfalls.
- **React**: objects, arrays and functions not created inline in render when they cross a memo boundary; constants hoisted out of the component; `key` stable and not an index over a reordering list; effects only for synchronising with something outside React - anything derivable computed during render instead; every subscription cleaned up.
- **Next App Router**: `'use client'` pushed as far down the tree as possible; server-only data and secrets never crossing into a client component; data fetched in the server layer rather than an effect; route handlers used for what they are for.
- **TypeScript**: no `any`, no `as unknown as`, no `@ts-ignore` without a documented boundary reason; discriminated unions instead of many optional fields; `satisfies` where a literal must keep its narrow type.
- **react-hook-form + zod**: schema as the single source of truth, resolver wired, no parallel manual validation, no controlled/uncontrolled mixing.

## Axis 3: Craft

Name the smell, then the move. Fowler's vocabulary applies to components too - Duplicated Code, Long Function, Feature Envy, Data Clumps, Primitive Obsession, Speculative Generality, Middle Man - plus the component-specific ones: prop drilling past two levels, a component doing both data access and presentation, a `useEffect` chain that is really derived state.

Render performance, with evidence rather than reflex:
- what actually triggers a re-render, and whether it is measurable;
- `memo`/`useMemo`/`useCallback` added without a memo boundary to protect - that is cost, not optimisation;
- long lists rendered without virtualisation;
- heavy modules imported statically where a dynamic import would do;
- sequential awaits that could run together.

Do not recommend memoisation unless you can name the boundary it protects.

## Findings

Every finding must cite one of:
- a repo rule plus the file it comes from;
- a smell name plus the quoted hunk;
- a library's intended usage plus the call site.

Include severity, confidence, evidence, impact, the named move, and a verification step when uncertain.
Findings are hypotheses. Say which ones you verified and how.
