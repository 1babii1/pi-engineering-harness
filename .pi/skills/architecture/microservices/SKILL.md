---
name: microservices
description: Use for service decomposition, cross-service workflows, event-driven design, and microservice patterns.
---
# Microservices

- Prefer a modular monolith until separate services have a concrete benefit.
- Decompose around business capabilities / bounded ownership, not technical layers.
- A service owns its data; other services communicate through contracts, not direct table access.
- Database-per-service may mean private tables/schema, not necessarily a separate physical server.
- Use synchronous HTTP/RPC when the caller needs an immediate result.
- Use asynchronous messaging for decoupling, fan-out, long-running work, or load smoothing.
- If one business operation changes DB state and publishes an integration event, consider Transactional Outbox.
- Assume at-least-once delivery; make consumers idempotent.
- Use Saga only for transactions spanning autonomous services when a local transaction cannot solve the problem.
- Use API Gateway/BFF only when client/service topology benefits from it.
- Service templates should standardize health checks, telemetry, configuration, security, and resilience.
