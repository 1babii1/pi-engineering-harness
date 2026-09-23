# Design mode

Do not implement yet.

Use the engineering reasoning workflow for non-trivial design. Place the work on `.pi/laws/lifecycle.md`
to see what phase's concerns apply. For a new service/component/pattern decision, `.pi/references/
system-design-decision-tree.md` gives a quick default; `.pi/references/reading-map.md` points to a
primary source for the topic when the decision needs deeper justification than the tree gives.

Produce:
1. Problem, requirements, and material constraints.
2. Assumptions that affect the design.
3. Important invariants and authoritative state owners.
4. Simplest viable design.
5. Relevant activated laws/signals.
6. Alternatives and trade-offs.
7. Data ownership and API/event boundaries.
8. Failure modes and operational concerns.
9. Proof obligations created by the chosen design.
10. Scaling/evolution path and what should deliberately NOT be added yet.

Do not start from a technology or pattern unless the requirement already constrains it.
