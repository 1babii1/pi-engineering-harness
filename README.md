# Pi Engineering Harness

A compact, production-oriented knowledge base for Pi and similar coding agents.

Primary stack:
- C# / .NET / ASP.NET Core / Minimal APIs
- PostgreSQL / Npgsql / Dapper / PostGIS
- React / TypeScript / Vite
- TanStack Query / Zustand / shadcn/ui
- Docker / Kubernetes / .NET Aspire
- OpenTelemetry / modern observability

## Philosophy
The root `AGENTS.md` stays small and always applicable. Detailed guidance lives in skills and references, so the agent loads it only when needed.

Core rule:

> Production-grade does not mean maximum complexity. Prefer simple -> observable -> reliable -> scalable.

## Structure
- `AGENTS.md` — global rules.
- `.pi/skills/coding` — implementation guidance.
- `.pi/skills/architecture` — system-design and distributed-system guidance.
- `.pi/skills/infrastructure` — Kubernetes, observability, Docker, Aspire.
- `.pi/skills/services` — reusable service blueprints.
- `.pi/references` — short decision trees and architecture notes.

## Recommended usage
Keep this repository as your canonical source. Copy or sync only the relevant `AGENTS.md` and `.pi` directory into a project.

Do not enable every architecture pattern by default. Skills are references, not mandatory architecture.
