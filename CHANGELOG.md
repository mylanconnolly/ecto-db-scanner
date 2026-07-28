# Changelog

## v0.5.0

### New features

- **Concurrent scans**: `EctoDBScanner.scan/1` no longer registers the repo under a fixed process name. Each scan starts its own anonymous repo instance (Ecto's dynamic-repo pattern), so multiple scans — against different databases or the same one — can run simultaneously from a single node without colliding on `EctoDBScanner.Repo`.
- **`:schemas` option** on `EctoDBScanner.scan/1`. When present, only the listed schemas are scanned. The filter is applied at the query level in every catalog query (tables, columns, constraints, sizes, indexes, sequences) so excluded schemas cost nothing — in particular, heuristic enum detection never samples their data.
- **`:exclude_schemas` option** on `EctoDBScanner.scan/1`. Schemas to skip in addition to the always-excluded system schemas (`information_schema`, `pg_catalog`, `pg_toast`). Applied at the query level like `:schemas`.
- **Table and column comments**: PostgreSQL comments (`COMMENT ON TABLE` / `COMMENT ON COLUMN`, via `obj_description` / `col_description`) are now extracted for tables, views, and materialized views. New `comment` field (`String.t() | nil`) on `%Result.Table{}` and `%Result.Column{}`.

### Internal changes

- The `EctoDBScanner.Scanner` Reactor's `repo` input is now an `%EctoDBScanner.RepoRef{}` (repo module + instance pid) instead of a bare repo module, and every query step takes an `options` argument. Each step (and each spawned enum-sampling task) binds the dynamic repo to its own process via `EctoDBScanner.RepoRef.bind/1` before querying. Callers invoking the Reactor directly can still pass a bare repo module — `RepoRef.bind/1` passes it through unchanged.

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
