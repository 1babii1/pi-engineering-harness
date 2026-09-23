# Core Engineering Laws

Each law has a *smell*: the observable sign it is being violated. Use smells when reviewing.

1. **State has one authoritative owner.**
   Smell: the same fact is written in two places with no named owner or sync path.
2. **Trust must be earned at boundaries.**
   Smell: input, a token claim, or a provider assertion (e.g. an email) is used before it is
   validated or before its "verified" flag is checked.
3. **Enforce invariants at the strongest practical owner.**
   Smell: uniqueness or state rules checked only in application code (check-then-act) when a
   constraint or aggregate could enforce them - including an ORM's own "does it exist?" pre-check
   (e.g. ASP.NET Identity's CreateAsync): it closes the gap for sequential callers but two
   concurrent ones can both pass it before either commits, so the database constraint is what
   actually stops the second one, and it does so by throwing, not by returning gracefully - handle
   both outcomes, and prove the race with a real concurrent test, not just the sequential case.
4. **Keep invariants local whenever possible.**
   Smell: a saga/distributed transaction guarding something one database transaction can guard.
5. **Complexity must earn its existence.**
   Smell: new infrastructure or abstraction with no measured problem it solves.
6. **Architecture follows requirements, constraints, and trade-offs.**
   Smell: a pattern chosen before the constraints were written down.
7. **Boundaries must be explicit and enforceable.**
   Smell: a layer/module rule that exists only by convention, with no test or analyzer.
8. **Depend on the smallest sufficient surface.**
   Smell: wide interfaces, broad permissions, or whole-framework references for one call.
9. **Public contracts change deliberately.**
   Smell: a field, event, status, or error code changed without listing its consumers.
10. **Copies create consistency obligations.**
    Smell: a cache, index, or projection with no staleness bound and no rebuild path.
11. **Identity must be stable and meaningful.**
    Smell: a mutable or non-unique attribute (email, name) used as the key; provider subject
    ignored.
12. **Lifetime follows ownership.**
    Smell: something outlives what depends on it or is retired while dependents are still live -
    a parent deleted while children still reference it, a cache/connection/lease held past the
    request it served, a key retired while tokens it protects are valid, a session surviving a
    password change.
13. **Failure is part of normal operation.**
    Smell: a remote call with no timeout or retry classification; only happy-path tests.
14. **Recovery must not amplify failure.**
    Smell: unbounded retries, retry storms, restart loops, retries of non-idempotent work.
15. **Every important claim needs matching evidence.**
    Smell: "safe / fast / compatible / tested" backed by evidence about something else
    (it compiles, so the migration is safe; the test is green but was never seen failing).

Use `.pi/laws/signals.md` to activate only the relevant laws and
`.pi/laws/proof-obligations.md` to derive evidence requirements.
