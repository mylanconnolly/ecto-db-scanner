# EctoDBScanner

A PostgreSQL database scanner that connects to a database at runtime, discovers its full structure, maps column types to generalized Elixir types, and detects enum-like columns.

## Features

- Discover schemas, tables, views, and materialized views
- Map PostgreSQL types to generalized Elixir types (`:string`, `:integer`, `:datetime`, etc.)
- Detect primary key and foreign key constraints
- Detect PostgreSQL ENUM types with their defined values
- Heuristic detection of enum-like string columns based on cardinality
- Expose column defaults and nullability
- Extract table and column comments (`COMMENT ON ...`)
- Scope scans to specific schemas (`:schemas`) or skip schemas (`:exclude_schemas`)
- Safe to run concurrently — each scan uses its own anonymous repo instance
- Parallel scan execution via [Reactor](https://hexdocs.pm/reactor) pipeline

## Installation

Add `ecto_db_scanner` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:ecto_db_scanner, "~> 0.1.0"}
  ]
end
```

## Usage

```elixir
{:ok, database} = EctoDBScanner.scan(
  hostname: "localhost",
  username: "postgres",
  password: "postgres",
  database: "my_db",
  port: 5432
)

# Returns:
# %EctoDBScanner.Result.Database{
#   schemas: [
#     %EctoDBScanner.Result.Schema{
#       name: "public",
#       tables: [
#         %EctoDBScanner.Result.Table{
#           name: "users",
#           type: :table,
#           comment: "Application user accounts",
#           columns: [
#             %EctoDBScanner.Result.Column{
#               name: "id",
#               type: :integer,
#               nullable: false,
#               primary_key: true,
#               foreign_key: nil,
#               default: "nextval('users_id_seq'::regclass)",
#               enum_values: nil,
#               comment: nil
#             },
#             %EctoDBScanner.Result.Column{
#               name: "status",
#               type: :string,
#               nullable: false,
#               primary_key: false,
#               foreign_key: nil,
#               default: nil,
#               enum_values: ["active", "inactive", "pending"],
#               comment: "Account lifecycle state"
#             },
#             ...
#           ]
#         },
#         ...
#       ]
#     },
#     ...
#   ]
# }
```

See the `EctoDBScanner.scan/1` docs for the full list of options, including
`:schemas` / `:exclude_schemas` for scoping a scan to particular schemas and
the `ANALYZE` / enum-detection knobs.

## Type Mapping

| PostgreSQL types | Elixir type |
|---|---|
| `int2`, `int4`, `int8`, `serial`, `bigserial`, `smallserial` | `:integer` |
| `float4`, `float8`, `numeric` | `:float` |
| `bool` | `:boolean` |
| `varchar`, `text`, `char`, `bpchar`, `citext`, `name` | `:string` |
| `date` | `:date` |
| `time`, `timetz` | `:time` |
| `timestamp` | `:naive_datetime` |
| `timestamptz` | `:datetime` |
| `uuid` | `:uuid` |
| `json`, `jsonb` | `:map` |
| `bytea` | `:binary` |
| `inet`, `cidr`, `macaddr`, `macaddr8` | `:string` |
| `_<type>` (array prefix) | `{:array, <mapped_type>}` |
| User-defined enum | `:string` (with `enum_values` populated) |
| Anything else | `{:unknown, "raw_type_name"}` |

## License

MIT - see [LICENSE](LICENSE) for details.
