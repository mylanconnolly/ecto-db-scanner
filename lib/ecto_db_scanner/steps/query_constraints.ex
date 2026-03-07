defmodule EctoDBScanner.Steps.QueryConstraints do
  use Reactor.Step

  import Ecto.Query

  @system_schemas ["information_schema", "pg_catalog", "pg_toast"]

  @impl true
  def run(%{repo: repo}, _context, _options) do
    primary_keys = query_primary_keys(repo)
    foreign_keys = query_foreign_keys(repo)

    {:ok, %{primary_keys: primary_keys, foreign_keys: foreign_keys}}
  end

  defp query_primary_keys(repo) do
    from(tc in "table_constraints",
      prefix: "information_schema",
      join: kcu in "key_column_usage",
      on: tc.constraint_name == kcu.constraint_name and tc.table_schema == kcu.table_schema,
      prefix: "information_schema",
      where: tc.constraint_type == "PRIMARY KEY",
      where: tc.table_schema not in @system_schemas,
      order_by: [kcu.table_schema, kcu.table_name, kcu.ordinal_position],
      select: {kcu.table_schema, kcu.table_name, kcu.column_name}
    )
    |> repo.all()
    |> MapSet.new()
  end

  defp query_foreign_keys(repo) do
    from(tc in "table_constraints",
      prefix: "information_schema",
      join: kcu in "key_column_usage",
      on: tc.constraint_name == kcu.constraint_name and tc.table_schema == kcu.table_schema,
      prefix: "information_schema",
      join: ccu in "constraint_column_usage",
      on:
        tc.constraint_name == ccu.constraint_name and
          tc.constraint_schema == ccu.constraint_schema,
      prefix: "information_schema",
      where: tc.constraint_type == "FOREIGN KEY",
      where: tc.table_schema not in @system_schemas,
      order_by: [kcu.table_schema, kcu.table_name, kcu.column_name],
      select: {
        kcu.table_schema,
        kcu.table_name,
        kcu.column_name,
        ccu.table_schema,
        ccu.table_name,
        ccu.column_name
      }
    )
    |> repo.all()
    |> Map.new(fn {schema, table, column, ref_schema, ref_table, ref_column} ->
      {{schema, table, column}, %{schema: ref_schema, table: ref_table, column: ref_column}}
    end)
  end
end
