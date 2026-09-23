Re-run EXPLAIN ANALYZE against the same query after adding the index and confirm the plan actually
uses it, not just that the index exists. Report the real before/after numbers: 800ms -> 42ms in this
case, measured the same way both times. If the plan still shows a sequential scan, the index does not
match the query (wrong column order/direction) and nothing has actually improved.
