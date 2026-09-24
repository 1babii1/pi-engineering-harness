---
name: pi-production-audit
description: Cross-cutting production-readiness audit covering failure modes, observability, delivery, resilience and operational safety.
---
# Production Readiness Audit

Audit only. Do not change code or infrastructure unless explicitly asked.

## Review
- health/readiness behavior;
- structured logs without sensitive data;
- traces across important boundaries;
- metrics for latency, traffic, errors and saturation;
- alertable failure signals;
- timeouts on remote calls;
- bounded retries with backoff/jitter for transient failures;
- idempotency where retries or duplicate delivery can occur;
- graceful shutdown;
- migration safety and rollback path;
- backup/restore assumptions for stateful systems;
- deployment strategy;
- secrets/config separation;
- dependency failure modes;
- queue depth/DLQ where messaging exists.

`.pi/references/production-service-checklist.md` is the checklist this audit walks; use it, do not
re-derive it from memory, and note which items do not apply and why.

## Rules
Production-grade does not mean maximum complexity.
Do not recommend Kubernetes, queues, caches, replicas or microservices unless a concrete requirement/problem justifies them.
