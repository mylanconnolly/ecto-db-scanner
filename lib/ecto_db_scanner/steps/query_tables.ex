defmodule EctoDBScanner.Steps.QueryTables do
  use Reactor.Step

  import Ecto.Query

  alias EctoDBScanner.InformationSchema
  alias EctoDBScanner.RepoRef
  alias EctoDBScanner.SchemaScope

  @included_types ["BASE TABLE", "VIEW"]

  @impl true
  def run(%{repo: repo_ref} = arguments, _context, _options) do
    repo = RepoRef.bind(repo_ref)
    options = Map.get(arguments, :options, %{})

    tables =
      from(t in InformationSchema.Table,
        as: :schema_scope,
        where: t.table_type in @included_types,
        select: {t.table_schema, t.table_name, t.table_type},
        order_by: [t.table_schema, t.table_name]
      )
      |> SchemaScope.apply_scope(options, :table_schema)
      |> repo.all()

    mat_views = query_materialized_views(repo, options)

    all_tables = tables ++ mat_views

    row_counts = query_row_counts(repo, options)
    comments = query_table_comments(repo, options)

    tables_with_counts =
      Enum.map(all_tables, fn {schema, table, table_type} ->
        count = Map.get(row_counts, {schema, table}, 0)
        type = map_table_type(table_type)
        comment = Map.get(comments, {schema, table})
        {schema, table, count, type, comment}
      end)

    {:ok, tables_with_counts}
  end

  defp query_materialized_views(repo, options) do
    from(m in "pg_matviews",
      prefix: "pg_catalog",
      as: :schema_scope,
      order_by: [m.schemaname, m.matviewname],
      select: {m.schemaname, m.matviewname, "MATERIALIZED VIEW"}
    )
    |> SchemaScope.apply_scope(options, :schemaname)
    |> repo.all()
  end

  # Uses planner statistics (pg_class.reltuples) rather than count(*). On large
  # tables count(*) can time out; reltuples is maintained by ANALYZE/autovacuum
  # and is sufficient for downstream heuristics (enum detection thresholds).
  # Returns 0 for relations that have never been analyzed (reltuples = -1).
  defp query_row_counts(repo, options) do
    from(c in "pg_class",
      prefix: "pg_catalog",
      join: n in "pg_namespace",
      as: :schema_scope,
      on: c.relnamespace == n.oid,
      prefix: "pg_catalog",
      where: c.relkind in ["r", "m", "v", "p"],
      select: {n.nspname, c.relname, fragment("GREATEST(?::bigint, 0)", c.reltuples)}
    )
    |> SchemaScope.apply_scope(options, :nspname)
    |> repo.all()
    |> Map.new(fn {schema, table, count} -> {{schema, table}, count} end)
  end

  # Table/view/matview comments live in pg_description; information_schema has
  # no notion of comments, so they come from obj_description on pg_class.
  defp query_table_comments(repo, options) do
    from(c in "pg_class",
      prefix: "pg_catalog",
      join: n in "pg_namespace",
      as: :schema_scope,
      on: c.relnamespace == n.oid,
      prefix: "pg_catalog",
      where: c.relkind in ["r", "m", "v", "p"],
      select: {n.nspname, c.relname, fragment("obj_description(?, 'pg_class')", c.oid)}
    )
    |> SchemaScope.apply_scope(options, :nspname)
    |> repo.all()
    |> Enum.reduce(%{}, fn
      {_schema, _table, nil}, acc -> acc
      {schema, table, comment}, acc -> Map.put(acc, {schema, table}, comment)
    end)
  end

  defp map_table_type("BASE TABLE"), do: :table
  defp map_table_type("VIEW"), do: :view
  defp map_table_type("MATERIALIZED VIEW"), do: :materialized_view
end
