---
name: react-frontend
description: Use for React, TypeScript, Vite, TanStack Query, Zustand, shadcn/ui, and frontend reviews.
---
# React + TypeScript

- Keep TypeScript strict. Avoid `any` and unsafe casts.
- Components should have one clear responsibility.
- Prefer composition and pure rendering.
- `useEffect` is for synchronization with external systems, not derived state or ordinary event handling.
- Use the smallest appropriate state owner:
  - local UI state -> `useState` / `useReducer`
  - server state -> TanStack Query
  - shared client-only state -> Zustand
- Do not copy TanStack Query server state into Zustand without a concrete synchronization requirement.
- Use stable query keys and mutations for server writes.
- Invalidate or update the smallest relevant cache scope.
- Do not fetch manually in `useEffect` when TanStack Query should own the request.
- Do not add `useMemo`, `useCallback`, or `memo` without a measured or clear reason.
- Use existing shadcn/ui components before creating equivalents.
- Preserve semantic HTML, keyboard access, and accessibility.
- Prefer generated OpenAPI API types/clients instead of manually duplicating backend contracts.
