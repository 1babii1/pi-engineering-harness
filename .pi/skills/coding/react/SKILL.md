---
name: react-frontend
description: "Use for React/TypeScript coding rules and reviews in a repository that has this harness: Next.js App Router, Vite, TanStack Query, Zustand, shadcn/ui. End-to-end frontend work (architecture, accessibility, performance, release readiness) is orchestrated by `frontend-core`; this skill is the rule checklist it relies on."
---
# React + TypeScript

- Keep TypeScript strict. Avoid `any` and unsafe casts.
- Components should have one clear responsibility.
- Prefer composition and pure rendering.
- `useEffect` is for synchronization with external systems, not derived state or ordinary event handling.
- Use the smallest appropriate state owner:
  - local UI state -> `useState` / `useReducer`
  - server state -> TanStack Query
  - shared client-only state -> Zustand (or the project's existing equivalent) when it must cross components that do not share a parent
- Do not copy TanStack Query server state into Zustand without a concrete synchronization requirement.
- Use stable query keys and mutations for server writes.
- Invalidate or update the smallest relevant cache scope.
- Do not fetch manually in `useEffect` when TanStack Query should own the request.
- Do not add `useMemo`, `useCallback`, or `memo` without a measured or clear reason.
- Use existing shadcn/ui components before creating equivalents.
- Preserve semantic HTML, keyboard access, and accessibility.
- Prefer generated OpenAPI API types/clients instead of manually duplicating backend contracts.

## Next.js App Router
- Server Components by default; add `'use client'` only to the smallest subtree that actually
  needs state, effects, event handlers, or a browser API - not to a whole page or layout.
- Fetch data and read secrets/API keys in Server Components; do not pass them as props into a
  Client Component or import server-only modules from client code (guard with the `server-only`
  package if the boundary is not obvious from the file).
- Put context providers as deep in the tree as practical (wrapping `{children}`, not the whole
  `<html>`), so the static parts of the tree stay server-rendered.
- Route handlers are for what an external caller or webhook needs; page data fetching belongs in
  the Server Component, not a route handler called from an effect.
