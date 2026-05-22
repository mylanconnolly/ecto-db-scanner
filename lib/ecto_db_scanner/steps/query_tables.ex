defmodule EctoDBScanner.Steps.QueryTables do
  use Reactor.Step

  import Ecto.Query

  alias EctoDBScanner.InformationSchema

  @system_schemas ["information_schema", "pg_catalog", "pg_toast"]
  @included_types ["BASE TABLE", "VIEW"]

  @impl true
  def run(%{repo: repo}, _context, _options) do
    tables =
      from(t in InformationSchema.Table,
        where: t.table_type in @included_types,
        where: t.table_schema not in @system_schemas,
        select: {t.table_schema, t.table_name, t.table_type},
        order_by: [t.table_schema, t.table_name]
      )
      |> repo.all()

    mat_views = query_materialized_views(repo)

    all_tables = tables ++ mat_views

    row_counts = query_row_counts(repo)

    tables_with_counts =
      Enum.map(all_tables, fn {schema, table, table_type} ->
        count = Map.get(row_counts, {schema, table}, 0)
        type = map_table_type(table_type)
        {schema, table, count, type}
      end)

    {:ok, tables_with_counts}
  end

  defp query_materialized_views(repo) do
    from(m in "pg_matviews",
      prefix: "pg_catalog",
      where: m.schemaname not in @system_schemas,
      order_by: [m.schemaname, m.matviewname],
      select: {m.schemaname, m.matviewname, "MATERIALIZED VIEW"}
    )
    |> repo.all()
  end

  # Uses planner statistics (pg_class.reltuples) rather than count(*). On large
  # tables count(*) can time out; reltuples is maintained by ANALYZE/autovacuum
  # and is sufficient for downstream heuristics (enum detection thresholds).
  # Returns 0 for relations that have never been analyzed (reltuples = -1).
  defp query_row_counts(repo) do
    from(c in "pg_class",
      prefix: "pg_catalog",
      join: n in "pg_namespace",
      on: c.relnamespace == n.oid,
      prefix: "pg_catalog",
      where: c.relkind in ["r", "m", "v", "p"],
      where: n.nspname not in @system_schemas,
      select: {n.nspname, c.relname, fragment("GREATEST(?::bigint, 0)", c.reltuples)}
    )
    |> repo.all()
    |> Map.new(fn {schema, table, count} -> {{schema, table}, count} end)
  end

  defp map_table_type("BASE TABLE"), do: :table
  defp map_table_type("VIEW"), do: :view
  defp map_table_type("MATERIALIZED VIEW"), do: :materialized_view
end
