---
name: pi-database-postgres
description: "Use for PostgreSQL, Npgsql, Dapper, and EF Core rules: SQL design, indexes and ORDER BY direction, migrations, transactions, query reviews. Whole data-layer work (caching, backups, PII retention, tenancy) belongs to `data-core`."
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

## Composite indexes for mixed-direction ORDER BY

A composite index only lets the planner skip sorting when its column order **and each
column's direction** match the query's ORDER BY exactly. `ORDER BY a DESC, b ASC, c ASC`
needs an index declared with that same per-column direction - a plain ascending index on
`(a, b, c)` does not serve it, even though the columns are already listed correctly, and a
backward scan does not fix it either: reversing an all-ascending index flips every column's
direction at once, not just the one that needed flipping.

Confirm both the index and the plan, not just one:
- Read the index back from the catalog (`\d table` / `pg_indexes.indexdef` /
  `SELECT indexdef ...`) and check the printed direction per column, not just that the
  columns are present. In EF Core, mixed-direction composite indexes need
  `.IsDescending(true, false, false)` (per-column bools) on `HasIndex` - the default
  Fluent API call creates every column ascending regardless of the query's ORDER BY.
- Then re-run EXPLAIN ANALYZE against the *actual* generated index, not a hand-written
  ad-hoc one used earlier to validate the idea - they are not guaranteed to match, and a
  mismatch here silently produces a worse plan than no index at all: an ad-hoc "prove
  the concept" index and the ORM's default output can differ in exactly this direction
  field, and only the live index the application will actually run against verifies the
  fix.

## Migrations (EF Core / PostgreSQL)

A migration is code that runs once against data you cannot see. Treat the generated file as a
draft to review, not as output to trust.

- **Read what was generated.** A renamed property becomes drop-column + add-column, which destroys
  the data; replace it with `RenameColumn`. The scaffolder warns about possible data loss - do not
  dismiss the warning.
- **Transform data in steps:** add the new column nullable, populate it, make it required, drop the
  old one. Use `Sql` for computed values and `InsertData/UpdateData/DeleteData` for fixed rows. Do
  not use the current `DbContext` or entity classes inside a migration: they change later and old
  migrations must keep compiling and behaving the same.
- **New constraint on existing data** (unique, foreign key, NOT NULL): first query for rows that
  violate it and decide what happens to them. A green build proves nothing about this.
- **Large tables:** a plain `CREATE INDEX` blocks writes. `CREATE INDEX CONCURRENTLY` does not, but
  it cannot run inside a transaction (pass `suppressTransaction: true` to `migrationBuilder.Sql`),
  scans the table twice, and if it fails it leaves an INVALID index behind - drop it and retry.
- **Never edit or delete a migration that reached a shared/production database, and never hand-edit
  the model snapshot.** Add a corrective migration. `Down` only when the original values can really
  be rebuilt; otherwise fail explicitly and document restore-from-backup.
- **Catch a forgotten migration in CI:** a test asserting `context.Database.HasPendingModelChanges()`
  is false (EF Core 8+).
- **Prove the upgrade path:** apply the migration to a database holding representative historical
  data (a restored snapshot or a seeded fixture), not only to an empty one. See
  `.pi/laws/proof-obligations.md` (Migration).
