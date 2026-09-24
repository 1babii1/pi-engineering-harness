---
name: pi-system-design
description: Use for architecture decisions, scaling, service boundaries, APIs, storage, caching, messaging, and production design.
---
# System Design

Start with requirements:
- functional requirements
- traffic and growth
- latency targets
- availability requirements
- consistency requirements
- data size and access patterns
- security/compliance
- failure tolerance
- team/ownership constraints

Prefer the simplest architecture satisfying them.

Decision order:
1. Can one service + one database solve it safely?
2. Can a modular monolith preserve boundaries?
3. Is a separate service justified by independent deployment/scaling/ownership/reliability?
4. Does communication need an immediate result (sync) or decoupling/load absorption/fan-out (async)?
5. Add cache, queue, sharding, CQRS, or distributed transactions only when their problem exists.

Always discuss trade-offs rather than presenting a pattern as universally best.

See `.pi/references/system-design-decision-tree.md` for a quick default per decision point above,
and `.pi/references/reading-map.md` for where to read further when a choice needs more justification
than the tree gives.
