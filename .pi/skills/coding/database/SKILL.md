---
name: database-postgres
description: Use for PostgreSQL, Npgsql, Dapper, PostGIS, SQL design, indexes, transactions, and query reviews.
---
# PostgreSQL / Dapper / PostGIS

- Design from access patterns, not abstract normalization alone.
- Parameterize every query.
- Select only required columns.
- Use indexes for demonstrated filters, joins, sorting, and geospatial access patterns.
- Verify index usage with execution plans when performance matters.
- Avoid unnecessary round trips and N+1 queries.
- Keep transactions short.
- Use the narrowest Dapper cardinality method that matches expectations.
- Prefer explicit SQL over hidden magic when query behavior matters.
- Use PostGIS operators/functions and appropriate spatial indexes for geographic queries.
- Do not introduce Redis or another cache before identifying a real hot path or distributed-state need.
