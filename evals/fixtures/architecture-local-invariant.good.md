Order and OrderItems live in one service and one PostgreSQL database, so a single local
transaction guarantees the invariant. A saga is not needed here: it would add compensation logic,
partial-failure states and ordering problems for no benefit. Insert the order and its items in one
transaction and enforce the rule with constraints.
