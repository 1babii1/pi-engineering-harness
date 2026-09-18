---
name: code-review
description: Perform a senior/lead production code review.
---
# Code Review

Prioritize:
1. Correctness and edge cases
2. Security
3. Data consistency and concurrency
4. API/contracts
5. Architecture boundaries
6. Database behavior
7. Reliability
8. Performance
9. Maintainability

For every real finding provide: severity, location, problem, impact, minimal fix.

Severity: BLOCKER / HIGH / MEDIUM / LOW.

Do not invent hypothetical issues with no realistic failure mode. Avoid style-only comments unless readability suffers.

Finally ask:
- Is there a simpler design?
- Is anything duplicated?
- Did complexity increase unnecessarily?
- Does this follow existing repository patterns?
