# Changelog

## v0.4.0

### Bug fixes

- **One slow column no longer aborts the whole scan**: heuristic enum detection's per-column `Task.async_stream` now uses `on_timeout: :kill_task`, so a column whose `TABLESAMPLE` sampling exceeds the timeout is dropped from the results instead of exiting the stream (which previously propagated out of the `DetectEnums` step and failed the entire `Reactor.run`). The default per-column timeout is also raised from 30 s to 60 s to match `Postgrex`'s default.

### New features

- **`:detect_enums` option** on `EctoDBScanner.scan/1` (default `true`). Set to `false` to skip the cardinality-based heuristic entirely on databases where even sampled enum detection is too slow. PostgreSQL `ENUM`-typed columns continue to be detected via catalog lookup.
- **`:enum_detection_timeout` option** on `EctoDBScanner.scan/1` (default `60_000`). Per-column sampling timeout in milliseconds for heuristic enum detection. Callers know more about their target DB's latency profile than the library does.
- **`:enum_detection_max_concurrency` option** on `EctoDBScanner.scan/1`. Number of columns to sample in parallel. Defaults to `pool_size - 1`.

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
