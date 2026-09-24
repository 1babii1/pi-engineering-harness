---
name: pi-resilience
description: Use for timeouts, retries, circuit breakers, bulkheads, queues, rate limits, and failure handling.
---
# Resilience

- Put explicit timeouts around remote calls.
- Retry only transient failures.
- Use exponential backoff and jitter where appropriate.
- Do not blindly retry validation, authorization, or permanent failures.
- Make retried operations idempotent.
- Use circuit breakers to stop repeated calls to an unhealthy dependency.
- Use bulkheads when workloads must not exhaust each other's resources.
- Use queues to absorb spikes and decouple processing rate from arrival rate.
- Use DLQs for poison/unprocessable messages, with monitoring and replay procedures.
- Add rate limiting by the correct identity: IP, user, tenant, API key, endpoint, or concurrency.
- Design graceful degradation and failure behavior explicitly.
