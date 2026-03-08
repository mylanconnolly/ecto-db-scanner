# Changelog

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
