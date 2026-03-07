# Changelog

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
