defmodule EctoDBScanner.Steps.QueryConstraints do
  use Reactor.Step

  import Ecto.Query

  @system_schemas ["information_schema", "pg_catalog", "pg_toast"]

  @impl true
  def run(%{repo: repo}, _context, _options) do
    primary_keys = query_primary_keys(repo)
    foreign_keys = query_foreign_keys(repo)
    check_constraints = query_check_constraints(repo)
    unique_constraints = query_unique_constraints(repo)

    {:ok,
     %{
       primary_keys: primary_keys,
       foreign_keys: foreign_keys,
       check_constraints: check_constraints,
       unique_constraints: unique_constraints
     }}
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

  defp query_check_constraints(repo) do
    from(con in "pg_constraint",
      prefix: "pg_catalog",
      join: c in "pg_class",
      on: con.conrelid == c.oid,
      prefix: "pg_catalog",
      join: n in "pg_namespace",
      on: c.relnamespace == n.oid,
      prefix: "pg_catalog",
      where: con.contype == "c",
      where: n.nspname not in @system_schemas,
      order_by: [n.nspname, c.relname, con.conname],
      select: {
        n.nspname,
        c.relname,
        con.conname,
        fragment("pg_get_constraintdef(?)", con.oid)
      }
    )
    |> repo.all()
    |> Enum.group_by(
      fn {schema, table, _, _} -> {schema, table} end,
      fn {_, _, name, expr} -> %{name: name, expression: expr} end
    )
  end

  defp query_unique_constraints(repo) do
    from(con in "pg_constraint",
      prefix: "pg_catalog",
      join: c in "pg_class",
      on: con.conrelid == c.oid,
      prefix: "pg_catalog",
      join: n in "pg_namespace",
      on: c.relnamespace == n.oid,
      prefix: "pg_catalog",
      where: con.contype == "u",
      where: n.nspname not in @system_schemas,
      order_by: [n.nspname, c.relname, con.conname],
      select: {
        n.nspname,
        c.relname,
        con.conname,
        con.conkey,
        con.conrelid
      }
    )
    |> repo.all()
    |> Enum.map(fn {schema, table, name, conkey, relid} ->
      columns = resolve_column_names(repo, relid, conkey)
      {schema, table, name, columns}
    end)
    |> Enum.group_by(
      fn {schema, table, _, _} -> {schema, table} end,
      fn {_, _, name, columns} -> %{name: name, columns: columns} end
    )
  end

  defp resolve_column_names(repo, relid, conkey) do
    from(a in "pg_attribute",
      prefix: "pg_catalog",
      where: a.attrelid == ^relid,
      where: a.attnum in ^conkey,
      order_by: a.attnum,
      select: a.attname
    )
    |> repo.all()
  end
end
