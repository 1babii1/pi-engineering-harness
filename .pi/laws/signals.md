# Engineering Signals

Signals activate deeper reasoning; they are not failures by themselves.

## Architecture / complexity
Triggers: new service, Kafka/queue/stream, Redis/cache, CQRS, Event Sourcing,
Saga, distributed lock, sharding, broad framework/abstraction, new sync service dependency.

Activate laws: local invariants, complexity, architecture drivers, boundaries, failure, evidence.

Ask:
- What concrete problem requires this?
- What simpler option is insufficient?
- What new failure/operational obligations appear?
- What would justify adding it later if deferred?

## State copies
Triggers: cache, replica, search index, projection, materialized view, copied server state.

Require:
- authoritative owner
- synchronization/update path
- tolerated staleness
- drift/rebuild/reconciliation path
- behavior when copy is unavailable

## Boundary / trust
Triggers: HTTP input, webhook, event/message, third-party API, localStorage, public contract,
privileged mutation.

Require:
- validation/narrowing
- authorization where relevant
- bounded external work
- explicit contract
- compatibility analysis for public changes

## Persistence / migration
Triggers: schema, constraints, indexes, transactions, data ownership.

Require:
- protected invariant
- concurrency behavior
- upgrade path from historical state
- mixed-version compatibility where applicable
- rollback/roll-forward implications

## Remote / async
Triggers: HTTP/gRPC, queue consumer, worker, webhook, scheduled job.

Require:
- timeout/deadline
- cancellation/shutdown
- retry classification and budget
- duplicate/idempotency semantics
- ordering scope if relevant
- exhaustion path

## High risk
Auth, credentials, payments, migrations, concurrency, public contracts,
distributed coordination, production infrastructure, destructive operations.
