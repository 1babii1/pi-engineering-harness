# Proof Obligations

For each material decision:

1. Decision
2. Activated laws
3. Obligations created by the decision
4. Matching evidence
5. Remaining assumptions / unverified properties

Do not create ceremony for trivial work.

## Common obligations

### Cache
- concrete latency/capacity problem
- authoritative owner
- staleness allowance
- invalidation/update semantics
- miss/stampede behavior
- outage behavior
- evidence that it improves the target bottleneck

### Queue / stream
- why async decoupling/buffering/fan-out is needed
- duplicate consequences / idempotency
- ordering scope
- retry + exhaustion
- poison-message handling
- backlog growth/drain strategy
- schema evolution

### New service
- independent runtime reason
- owned data and public contract
- failure behavior of dependencies
- observability and operational owner
- why an in-process module is insufficient

### Distributed lock
- why owner-local enforcement is insufficient
- lease expiry
- stale-owner behavior
- fencing/generation when stale owners can still mutate

### Public API / event
- consumers
- compatibility class
- rollout/migration path
- retry/idempotency semantics for side effects
- authorization boundaries
- stable error/failure semantics

### Migration
- upgrade path from existing state
- production lock/runtime risk
- mixed-version compatibility if relevant
- backfill/cleanup strategy
- rollback or roll-forward behavior
- representative migration verification

## Evidence mapping examples
- compiles -> compiler
- type-safe -> type checker
- architecture boundary -> architecture/dependency test
- backward compatible -> contract/schema diff or contract test
- migration safe -> upgrade-path test on representative state
- idempotent -> duplicate-execution test
- thread-safe -> concurrency-focused verification
- handles N rps -> realistic load test
- recovers from dependency failure -> controlled failure/recovery test
