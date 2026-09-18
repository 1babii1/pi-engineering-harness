---
name: background-jobs
description: Use for workers, queues, scheduled jobs, long-running processing, and retryable jobs.
---
# Background Jobs Blueprint

Assume a worker can crash at any point.

Design for:
- at-least-once execution
- idempotency
- timeout/cancellation
- retry with backoff
- poison-message/DLQ behavior
- progress/status where needed
- graceful shutdown
- observability
- safe replay

Persist enough state to distinguish never-started, in-progress, succeeded, failed, and retryable work when business requirements need it.
