---
name: pi-backend-audit
description: Read-only audit for C#/.NET, ASP.NET Core, APIs, database access, concurrency, performance, reliability and observability.
---
# Backend Audit

Audit only. Do not modify code unless explicitly asked.

## Passes
1. Architecture boundaries.
2. API contracts and HTTP semantics.
3. Authentication and authorization boundaries.
4. Async/concurrency correctness.
5. Database behavior.
6. Reliability and failure handling.
7. Performance hot paths.
8. Observability.
9. Test strategy.

## .NET checks
Look for:
- `.Result`, `.Wait()`, `async void` outside event handlers;
- fire-and-forget work without ownership;
- missing cancellation on meaningful I/O;
- incorrect DI lifetimes;
- static mutable state;
- unbounded in-memory collections;
- exceptions used for normal control flow;
- sync I/O in server paths.

## Database
Look for SQL injection, N+1, `SELECT *`, unnecessary round trips, long transactions, missing pagination, suspicious index gaps and race conditions.
Do not prescribe indexes without query evidence; recommend `EXPLAIN (ANALYZE, BUFFERS)` when verification is needed.

## Architecture
Report broken boundaries and concrete coupling, not differences in architectural taste.

## Findings
For each finding include severity, confidence, evidence, impact, verification step when uncertain, and minimal recommendation.
