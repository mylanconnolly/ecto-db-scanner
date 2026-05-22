# Changelog

## v0.3.0

### Improvements

- **Avoid `count(*)` timeouts on large tables**: `QueryTables` now derives per-table row counts from `pg_class.reltuples` (planner statistics) instead of running `SELECT count(*)` against every table. On databases with multi-million / billion-row tables this removes the most common scan-time timeout.
- **Sample large tables in heuristic enum detection**: `EnumDetector` now uses `TABLESAMPLE SYSTEM` to bound the work of `COUNT(DISTINCT col)` and distinct-value collection on tables larger than 100k rows, so a single huge table can no longer drag the whole scan into a timeout. Tables below the threshold continue to scan in full.

### New features

- **`:analyze` option** on `EctoDBScanner.scan/1` (default `true`). Runs `ANALYZE` before scanning so the `reltuples` statistics used for row counts and sampling are fresh. Set `analyze: false` if statistics are already current or the connecting role lacks permission to analyze.

## v0.2.0 (2026-03-07)

### New features

- **Database size**: Report total database size in bytes via `%Result.Database{size_bytes: ...}`
- **Table sizes**: Report table size, index size, and total size in bytes for each table
- **Row counts**: Estimated row counts per table via PostgreSQL statistics (`reltuples`)
- **Index discovery**: Discover non-primary-key indexes with name, type (btree, gin, etc.), uniqueness, and column list
- **Sequence discovery**: Discover sequences with current value and `owned_by` column resolution
- **Check constraints**: Discover check constraints with name and expression
- **Unique constraints**: Discover unique constraints with name and column list

### Improvements

- Updated Reactor dependency from `~> 0.13` to `~> 1.0`

## v0.1.0 (2026-03-06)

### Initial release

- Connect to a PostgreSQL database at runtime and discover its full structure
- Discover schemas, tables, views, and materialized views
- Discover columns with type mapping from PostgreSQL types to generalized Elixir types
- Detect primary key and foreign key constraints
- Detect PostgreSQL ENUM types with their defined values
- Heuristic detection of enum-like string columns based on cardinality analysis
- Expose column default values and nullability
- Parallel execution of independent scan steps via Reactor pipeline
