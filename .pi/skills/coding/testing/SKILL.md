---
name: testing
description: Use when adding, reviewing, or selecting tests.
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
