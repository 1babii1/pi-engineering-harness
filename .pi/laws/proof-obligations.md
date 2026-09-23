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

### Destructive / irreversible operation
- who may perform it and what confirms intent (not just that the endpoint was called)
- what is reversible, for how long, and what is not - state it, do not assume
- blast radius: everything the operation cascades to (related rows, caches, derived events,
  other users' visible state), not just the row named in the request
- an audit trail identifying who did it, when, and to what
- a rate/scope limit on bulk variants, so one call cannot destroy far more than intended

### Migration
- upgrade path from existing state
- production lock/runtime risk
- mixed-version compatibility if relevant
- backfill/cleanup strategy
- rollback or roll-forward behavior
- representative migration verification

### Credential / authenticator change (password, email, 2FA, passkey, external link)
- who may perform it and what re-authentication proves it
- which existing sessions, refresh tokens, and outstanding reset/confirm tokens must die
- notification to the affected address/user
- the same rule on every path that reaches the change (recovery, admin, external login)

### External identity linking / provisioning
- the provider's "verified" assertion is required and missing means "not verified"
- linking to a pre-existing local account: that account's own address must be confirmed, or the
  unconfirmed row is taken over (its password removed, address confirmed, stamp rotated) - never
  inherited as-is (account pre-hijacking)
- the stable identity is the provider subject, not the email

### Token / key lifecycle
- lifetime of every token type and of the key that protects it (key retention >= longest token
  lifetime protected, counted from when the key stops being current)
- which key signs new tokens, and that old keys still validate until retention ends
- every cache that derives key material is invalidated on rotation (issuer AND validator)
- concurrent rotation by several instances is serialized (lock + re-check after acquiring it)
- private key material is encrypted at rest with a master key held outside the datastore, required
  in Production, and legacy plaintext rows are migrated

### Step-up / re-authentication
- the enforcing scheme (cookie vs bearer) can read the proof used
- the policy is registered (an unregistered policy is a 500, not a 403)
- expiry of the elevation

### Concurrency
- the invariant and its owner
- what happens when two actors collide, enforced in the store
- retries of side effects are idempotent

### Scheduled / background job
- safe to run twice at once and to skip a run
- failure is visible (log + alert), not swallowed
- effect is bounded when it falls behind

### Performance claim
- baseline number, target number, and where the time goes (plan/profile)
- the same measurement after the change

### Test evidence
- each regression test was observed failing without the fix
- the data separates the cases (past the cap, excluded row, second owner)
- reset/fixtures do not remove data the host needs to start

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
- password change ends other sessions -> sign in twice, change the password in one, prove the
  other's cookie is rejected
- unverified provider email rejected -> tests with the claim `false` AND absent, and nothing created
- key rotation works -> token issued before still validates after; token issued after carries a
  new key id; no restart between the two
- rate limit / lockout -> real repeated requests reach 429 / lockout; the per-account limit still
  holds from a different IP
- test guards the fix -> mutate the fix, watch that specific test fail, restore
- concurrency-safe (job/rotation) -> N parallel callers with separate contexts, effect happens
  exactly once; remove the lock and the test fails
- keys not readable from a database dump -> read the stored column and assert it is ciphertext, and
  that a token flow still works through it
- no secrets logged -> capture logs of the flow and search them for the token/code/password
- destructive operation is safe -> a test that it refuses without confirmation, and that the
  audit trail/cascade cleanup actually happened when confirmed
