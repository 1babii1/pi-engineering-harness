---
name: dotnet-backend
description: Use for C#, .NET, ASP.NET Core, Minimal APIs, backend architecture, and backend reviews.
---
# .NET Backend

- Prefer idiomatic modern C# and nullable reference types.
- Prefer composition over inheritance.
- Avoid static mutable state and reflection without a clear reason.
- Use async for I/O; never block with `.Result` or `.Wait()`.
- Propagate `CancellationToken` through meaningful async boundaries.
- Do not wrap naturally async server I/O in `Task.Run`.
- Keep endpoints thin: transport, auth, validation, mapping, status codes.
- Keep business logic outside endpoints.
- Use correct HTTP semantics and consistent error responses.
- Do not expose persistence models as public API contracts.
- Treat API contracts as stable interfaces.
- Parameterize SQL and never concatenate user input.
- Select only required columns and avoid N+1 queries.
- Keep transactions short and only as broad as needed for atomicity.
- Prefer explicit mapping for simple DTOs.
- Follow the existing validation strategy; add FluentValidation only when it improves non-trivial validation.
- Do not add MediatR/CQRS unless the project already uses it or the problem benefits from it.
- Do not raise the analyzer/warning baseline: new code adds no new warnings; suppress a rule only
  with a documented reason at the narrowest scope.
- Validate options at startup (`ValidateOnStart`) instead of failing on first use; refuse to start
  in Production when a security-relevant setting is missing rather than falling back silently.
- Schema changes go through migrations; see `coding/database` for review and safety rules.
