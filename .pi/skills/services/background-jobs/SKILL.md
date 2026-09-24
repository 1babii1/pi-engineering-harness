---
name: pi-background-jobs
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

## More than one instance

Decide explicitly whether the job may run on two instances at once (a rolling deploy always
overlaps old and new; a second replica, or a startup racing a scheduled run, does the same).
In-memory schedulers (for example Quartz's RAM store) coordinate nothing across processes.

- Make the work idempotent, or serialize it. For a database-backed job the simplest serializer is
  a transaction-scoped advisory lock (PostgreSQL `pg_advisory_xact_lock`), or a clustered
  scheduler store.
- **Re-check the "is it due?" condition after taking the lock,** not before: otherwise every waiter
  passes the stale check and does the work in turn.
- Prove it with a test that launches several callers at once, each with its own connection/context,
  and asserts the effect happened exactly once. Verify the test by removing the lock and watching
  it fail.
- A job's failure must be visible: log it with context and surface it to whatever alerts you.
