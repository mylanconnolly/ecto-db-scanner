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

    tables_with_counts =
      Enum.map(all_tables, fn {schema, table, table_type} ->
        count =
          from(t in table, prefix: ^schema, select: count())
          |> repo.one()

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

  defp map_table_type("BASE TABLE"), do: :table
  defp map_table_type("VIEW"), do: :view
  defp map_table_type("MATERIALIZED VIEW"), do: :materialized_view
end
