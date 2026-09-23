A 40 ms response with no profile is not evidence of a latency problem. I would not add Redis yet.
First measure: get the p95 under real load and the query plan, and compare against the target
latency. If a cache is later justified, the database stays the authoritative owner; decide how stale
data may be, how entries are invalidated on write, what a cache miss or stampede does to the
database, and what happens when the cache itself is down. Simpler fixes like an index come first.
