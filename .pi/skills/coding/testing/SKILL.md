---
name: pi-testing
description: "Use when adding, reviewing, or selecting tests: proving a test can fail, seeding past boundaries, shared fixtures, failures that appear only in the full run. Test strategy, quality gates, and release verdicts belong to `qa-core`."
---
# Testing

- Test behavior, not implementation details.
- Prefer the smallest test level that gives confidence.
- Unit tests: pure domain/application logic.
- Integration tests: database, HTTP boundaries, authentication, serialization, infrastructure behavior.
- End-to-end tests: only critical user journeys.
- Add regression tests for confirmed bugs when practical.
- Avoid mocks for simple value objects or pure code.
- Do not mock the system under test.
- Keep tests deterministic and independent.

## Prove the test can fail

A test that passes against the bug it was written to catch is theater, and it is worse than
no test because it reports safety that is not there.

Before trusting a regression test, break the fix and watch that specific test fail, then
restore it. If it stays green, the test is wrong - not the code.

Watch for assertions that cannot distinguish the two cases:
- a cap or limit asserted with less data than the cap (a clamp to 200 and no clamp at all
  return the same rows when only 3 exist - seed past the boundary);
- a filter asserted with only matching rows present (seed a row that must be excluded);
- an ownership or scoping rule asserted with a single owner's data (seed a second owner);
- asserting only a status code where the defect changes the body, or vice versa.

State in the test what makes the boundary observable, so the next person does not
"simplify" the seeding and silently hollow the test out.

## A suite that only fails under load is not flaky, it is broken

Treat "passes alone, fails in the full run" as a defect with a cause, never as randomness
to be retried away. Find the cause before touching the assertion.

The usual culprits, in the order worth checking:
- a background service the test host starts that the tests do not need - it competes for
  the same resources and retries against infrastructure that does not exist in tests;
- one container per test class where one per assembly would do;
- shared state reset by one class while another is mid-run.

A useful tell is runtime: a suite that is both slow and load-sensitive is usually waiting
on something it should never have started. Compare the suite's duration before and after -
if the fix does not also make it markedly faster, the cause was probably something else.

When one project's test setup differs from its siblings', that difference is the first
place to look - the same "odd copy out" reasoning applies to test infrastructure.

## Shared fixtures and reset tools

Integration suites usually share one database/host across many test classes. The reset
between tests is part of the test infrastructure and fails in confusing ways.

- A "wipe every table" reset (Respawn, TRUNCATE loops, snapshot restore) also wipes rows the
  application host needs to boot: seeded roles, OAuth clients/scopes, signing keys,
  reference data. Exclude those tables from the reset explicitly, and have any test class
  that mutates that shared state restore it in its own setup rather than trusting the last
  class to have left it clean.
- Startup seeders may run lazily on the first access to the host (for example the first
  `factory.Services` touch), not at construction. A test that wipes the database before that
  first touch races the seeder.
- The failure signature of wiped bootstrap data is an error from deep inside the framework
  ("no signing/encryption key registered", "client not found") in tests that never touched
  that feature. Suspect the reset before suspecting the feature.
- Framework code that needs an `HttpContext` (sign-in managers, cookie sign-in) fails oddly
  when driven from a test outside a request. Assign the context deliberately instead of
  letting it be null.
