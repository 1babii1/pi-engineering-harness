# Engineering Signals

Signals activate deeper reasoning; they are not failures by themselves. Pick the signals that
materially apply; do not walk the whole list for routine work.

## Architecture / complexity
Triggers: new service, Kafka/queue/stream, Redis/cache, CQRS, Event Sourcing,
Saga, distributed lock, sharding, broad framework/abstraction, new sync service dependency.

Activate laws: local invariants, complexity, architecture drivers, boundaries, failure, evidence.
See `.pi/references/system-design-decision-tree.md` for a quick default and `reading-map.md` for a
primary source when the decision needs more justification than the tree gives.

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

## Identity / credentials / sessions
Triggers: login, registration, password or credential change, MFA/passkeys, session or token
issuance, OAuth/OIDC/OpenIddict, external identity provider, account recovery, email change,
account deletion, key or secret rotation, step-up/re-authentication.
Load `services/auth` (and `architecture/security`) for the concrete checks.

Require:
- responses and timing that do not reveal whether an account exists
- brute-force control that survives changing IPs (per-account) and cheap abuse control (per-IP)
- every credential/authenticator change ends the sessions and tokens it should end
- external assertions trusted only when verified (verified-email flag, subject as identity)
- token validation of issuer, audience, signature, lifetime, algorithm; short-lived access tokens
- key/secret lifetimes that outlast everything they protect, and a rotation that needs no restart
- re-authentication whose proof the enforcing scheme can actually read
- no secrets, tokens, codes, or passwords in logs or fixtures; key material encrypted at rest

## Concurrency / shared mutable state
Triggers: locks, parallel or fire-and-forget async work, background jobs on several instances,
counters, check-then-act, optimistic/pessimistic concurrency, retries that repeat side effects.

Require:
- the owner of the state and the invariant it protects
- enforcement in the store (constraint, atomic update, version) rather than a read-then-write
- behavior when two actors (requests, replicas, job runs) act at once
- a test that actually creates the contention - seeded against an aggregate that already
  has related rows, not only a freshly created one: a brand-new aggregate's own primary key
  can accidentally mask a missing constraint (the race "succeeds" because creating the
  parent row collided, not because the invariant you meant to test was enforced)

## Persistence / migration
Triggers: schema, constraints, indexes, transactions, data ownership.

Require:
- protected invariant
- concurrency behavior
- upgrade path from historical state
- mixed-version compatibility where applicable
- rollback/roll-forward implications
- index direction/order matching the query when sort order matters

## Remote / async
Triggers: HTTP/gRPC, queue consumer, worker, webhook, scheduled job.

Require:
- timeout/deadline
- cancellation/shutdown
- retry classification and budget
- duplicate/idempotency semantics
- ordering scope if relevant
- exhaustion path
- a decision, stated once, on what happens when the dependency is down (fail open or closed)

## Operations / observability
Triggers: new service, job, consumer, external dependency, or user-facing failure mode.

Require:
- a health signal that reflects user impact, not only "process is up"
- structured, secret-free logs with a correlation id
- an alertable failure path (dead-letter visibility, job failure surfaced)
- an owner for the alert

## New dependency
Triggers: adding a package/library, especially transitively (a new package can pull in
others you did not choose).

Require:
- check for known vulnerabilities before treating a successful build as done (`dotnet list
  package --vulnerable --include-transitive`, `npm audit`, or the ecosystem's equivalent) -
  a build succeeding says nothing about this
- a transitive vulnerability pinned to a fixed version, not left at whatever floor the new
  package happened to pull in

## Undocumented single-instance assumption
Triggers: reviewing architecture, adding a new service/consumer, anything holding
in-process state (SignalR groups, an in-memory cache, a singleton counter) that would stop
working correctly the moment more than one instance runs.

Ask explicitly, as its own pass separate from checking documented decisions still hold:
what is currently true only because there is exactly one instance, and is that written down
anywhere? A single-instance assumption that is correct today and genuinely fine to keep is
not the problem; one nobody wrote down is - it fails silently and specifically the moment
it stops being true, with no error to find it by.

## Performance claims
Triggers: "faster", caching, indexing, batching, memoization, "hot path".

Require:
- a measured baseline and a target
- the plan or profile that shows the bottleneck
- the same measurement after the change
Do not optimize without a number.

## Frontend state
Triggers: server data copied into client state, effects that mirror state, new data fetching.

Require:
- one owner per piece of state; server state in the server-state library
- loading, empty, error, and unauthorized states
- effects only to synchronize with something outside the framework

## Test evidence quality
Triggers: a regression test, a fix claim, an assertion about a limit/filter/ownership rule,
a test suite that is slow or fails only in the full run.

Require:
- the test was seen failing against the defect (break the fix, watch it go red, restore it)
- boundary data that distinguishes the cases (seed past the cap, include an excluded row, a
  second owner)
- shared fixtures/reset tools that do not wipe bootstrap data other tests need
- "passes alone, fails in the full run" treated as a defect with a cause

## High risk
Auth, credentials, payments, migrations, concurrency, public contracts,
distributed coordination, production infrastructure, destructive operations.

Require:
- a scope contract (goal, must preserve, out of scope) before changing code
- proof obligations written down and each matched to evidence
- negative tests (the attack, the failure, the wrong actor), not only the happy path
- a rollback or roll-forward statement for anything persistent or deployed
- an independent fresh-context review (`independent-verifier`) before completion
- an explicit list of what remains unverified
