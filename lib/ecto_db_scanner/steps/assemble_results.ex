defmodule EctoDBScanner.Steps.AssembleResults do
  use Reactor.Step

  alias EctoDBScanner.Result

  @impl true
  def run(
        %{
          tables: tables,
          columns: columns,
          enum_info: enum_info,
          constraints: constraints,
          sizes: sizes,
          indexes: indexes,
          sequences: sequences
        },
        _context,
        _options
      ) do
    %{
      primary_keys: primary_keys,
      foreign_keys: foreign_keys,
      check_constraints: check_constraints,
      unique_constraints: unique_constraints
    } = constraints

    %{database_size: database_size, table_sizes: table_sizes, row_counts: row_counts} = sizes

    table_types =
      Map.new(tables, fn {schema, table, _count, type} -> {{schema, table}, type} end)

    schemas =
      columns
      |> Enum.group_by(& &1.table_schema)
      |> Enum.sort_by(fn {schema_name, _} -> schema_name end)
      |> Enum.map(fn {schema_name, schema_columns} ->
        result_tables =
          schema_columns
          |> Enum.group_by(& &1.table_name)
          |> Enum.sort_by(fn {table_name, _} -> table_name end)
          |> Enum.map(fn {table_name, table_columns} ->
            table_key = {schema_name, table_name}

            result_columns =
              table_columns
              |> Enum.sort_by(& &1.ordinal_position)
              |> Enum.map(fn col ->
                key = {schema_name, table_name, col.column_name}
                enum_values = Map.get(enum_info, key)

                type =
                  case col.mapped_type do
                    {:unknown, _} when not is_nil(enum_values) -> :string
                    other -> other
                  end

                %Result.Column{
                  name: col.column_name,
                  type: type,
                  nullable: col.nullable,
                  enum_values: enum_values,
                  default: col.column_default,
                  primary_key: MapSet.member?(primary_keys, key),
                  foreign_key: Map.get(foreign_keys, key)
                }
              end)

            table_type = Map.get(table_types, table_key, :table)
            size_info = Map.get(table_sizes, table_key, %{})
            row_count = Map.get(row_counts, table_key, 0)

            result_indexes =
              indexes
              |> Map.get(table_key, [])
              |> Enum.map(fn idx ->
                %Result.Index{
                  name: idx.name,
                  type: idx.type,
                  unique: idx.unique,
                  columns: idx.columns
                }
              end)

            result_checks =
              check_constraints
              |> Map.get(table_key, [])
              |> Enum.map(fn cc ->
                %Result.CheckConstraint{name: cc.name, expression: cc.expression}
              end)

            result_uniques =
              unique_constraints
              |> Map.get(table_key, [])
              |> Enum.map(fn uc ->
                %Result.UniqueConstraint{name: uc.name, columns: uc.columns}
              end)

            %Result.Table{
              name: table_name,
              type: table_type,
              row_count: row_count,
              size_bytes: Map.get(size_info, :size_bytes, 0),
              index_size_bytes: Map.get(size_info, :index_size_bytes, 0),
              total_size_bytes: Map.get(size_info, :total_size_bytes, 0),
              columns: result_columns,
              indexes: result_indexes,
              check_constraints: result_checks,
              unique_constraints: result_uniques
            }
          end)

        result_sequences =
          sequences
          |> Map.get(schema_name, [])
          |> Enum.map(fn seq ->
            %Result.Sequence{
              name: seq.name,
              current_value: seq.current_value,
              owned_by: seq.owned_by
            }
          end)

        %Result.Schema{name: schema_name, tables: result_tables, sequences: result_sequences}
      end)

    {:ok, %Result.Database{size_bytes: database_size, schemas: schemas}}
  end
end
