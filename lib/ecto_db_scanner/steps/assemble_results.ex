defmodule EctoDBScanner.Steps.AssembleResults do
  use Reactor.Step

  alias EctoDBScanner.Result

  @impl true
  def run(
        %{tables: tables, columns: columns, enum_info: enum_info, constraints: constraints},
        _context,
        _options
      ) do
    %{primary_keys: primary_keys, foreign_keys: foreign_keys} = constraints

    table_types =
      Map.new(tables, fn {schema, table, _count, type} -> {{schema, table}, type} end)

    schemas =
      columns
      |> Enum.group_by(& &1.table_schema)
      |> Enum.sort_by(fn {schema_name, _} -> schema_name end)
      |> Enum.map(fn {schema_name, schema_columns} ->
        tables =
          schema_columns
          |> Enum.group_by(& &1.table_name)
          |> Enum.sort_by(fn {table_name, _} -> table_name end)
          |> Enum.map(fn {table_name, table_columns} ->
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

            table_type = Map.get(table_types, {schema_name, table_name}, :table)

            %Result.Table{name: table_name, type: table_type, columns: result_columns}
          end)

        %Result.Schema{name: schema_name, tables: tables}
      end)

    {:ok, %Result.Database{schemas: schemas}}
  end
end
