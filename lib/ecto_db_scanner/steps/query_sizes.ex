defmodule EctoDBScanner.Steps.QuerySizes do
  use Reactor.Step

  import Ecto.Query

  @system_schemas ["information_schema", "pg_catalog", "pg_toast"]

  @impl true
  def run(%{repo: repo}, _context, _options) do
    database_size = query_database_size(repo)
    table_sizes = query_table_sizes(repo)
    row_counts = query_row_counts(repo)

    {:ok, %{database_size: database_size, table_sizes: table_sizes, row_counts: row_counts}}
  end

  defp query_database_size(repo) do
    from(d in "pg_database",
      prefix: "pg_catalog",
      where: d.datname == fragment("current_database()"),
      select: fragment("pg_database_size(?)", d.oid)
    )
    |> repo.one()
  end

  defp query_table_sizes(repo) do
    from(c in "pg_class",
      prefix: "pg_catalog",
      join: n in "pg_namespace",
      on: c.relnamespace == n.oid,
      prefix: "pg_catalog",
      where: c.relkind in ["r", "m", "v"],
      where: n.nspname not in @system_schemas,
      select: {
        n.nspname,
        c.relname,
        fragment("pg_table_size(?)", c.oid),
        fragment("pg_indexes_size(?)", c.oid),
        fragment("pg_total_relation_size(?)", c.oid)
      }
    )
    |> repo.all()
    |> Map.new(fn {schema, table, table_size, index_size, total_size} ->
      {{schema, table},
       %{size_bytes: table_size, index_size_bytes: index_size, total_size_bytes: total_size}}
    end)
  end

  defp query_row_counts(repo) do
    from(c in "pg_class",
      prefix: "pg_catalog",
      join: n in "pg_namespace",
      on: c.relnamespace == n.oid,
      prefix: "pg_catalog",
      where: c.relkind in ["r", "m", "v"],
      where: n.nspname not in @system_schemas,
      select: {n.nspname, c.relname, fragment("?::bigint", c.reltuples)}
    )
    |> repo.all()
    |> Map.new(fn {schema, table, count} -> {{schema, table}, count} end)
  end
end
