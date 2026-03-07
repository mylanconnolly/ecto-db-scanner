defmodule EctoDBScanner.Steps.DetectEnums do
  use Reactor.Step

  alias EctoDBScanner.EnumDetector

  @impl true
  def run(%{repo: repo, tables: tables, columns: columns, pg_enums: pg_enums}, _context, _options) do
    pool_size = repo.config()[:pool_size] || 5

    # Map PG enum types to columns
    pg_enum_info =
      for col <- columns,
          col.data_type == "USER-DEFINED",
          values = Map.get(pg_enums, col.udt_name),
          not is_nil(values),
          into: %{} do
        {{col.table_schema, col.table_name, col.column_name}, values}
      end

    # Strip type from table tuples for heuristic detection (expects {schema, table, count})
    tables_with_counts =
      Enum.map(tables, fn {schema, table, count, _type} -> {schema, table, count} end)

    # Heuristic detection on string columns
    heuristic_info =
      EnumDetector.detect_heuristic_enums(repo, tables_with_counts, columns, pool_size)

    {:ok, Map.merge(heuristic_info, pg_enum_info)}
  end
end
