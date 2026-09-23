Two instances can both see the stale key and both mint one. Take a transaction-scoped PostgreSQL advisory lock
(pg_advisory_xact_lock) around the whole job and re-check whether rotation is due after acquiring the lock, so
the waiting instance sees the fresh key and does nothing. To prove it, launch eight concurrent callers, each with
its own DbContext, and assert exactly one new key exists; remove the lock and the test must fail.
