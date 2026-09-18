---
name: generic-backend
description: Use for backend code in a stack with no dedicated coding skill installed (anything other than .NET) - general-purpose correctness/security principles that hold regardless of language or framework.
---
# Generic Backend

No stack-specific skill is installed for this language/framework. These are the
language-agnostic principles that still apply; defer to the project's own conventions
(`.pi/project/conventions.md`) over anything below when they conflict.

- Parameterize every query; never build SQL/query strings by concatenating user input.
- Use the language's async/concurrency primitives for I/O; don't block an event loop or
  thread pool waiting on I/O that has a non-blocking form.
- Keep endpoints/handlers thin: transport, auth, validation, mapping, status codes -
  business logic belongs elsewhere.
- Do not expose persistence models directly as API contracts.
- Treat API contracts as stable interfaces once published.
- Select only required columns/fields and avoid N+1 queries.
- Keep transactions short and only as broad as needed for atomicity.
- Validate and sanitize all external input at the boundary.
- Do not introduce a framework, library, or architectural pattern (CQRS, event bus,
  sagas, extra layers) merely because it's available - only when the problem needs it.
