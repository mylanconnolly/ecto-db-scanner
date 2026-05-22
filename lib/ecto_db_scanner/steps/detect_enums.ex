defmodule EctoDBScanner.Steps.DetectEnums do
  use Reactor.Step

  alias EctoDBScanner.EnumDetector

  @impl true
  def run(arguments, _context, _step_options) do
    %{repo: repo, tables: tables, columns: columns, pg_enums: pg_enums} = arguments
    scan_options = Map.get(arguments, :options, %{})

    pg_enum_info =
      for col <- columns,
          col.data_type == "USER-DEFINED",
          values = Map.get(pg_enums, col.udt_name),
          not is_nil(values),
          into: %{} do
        {{col.table_schema, col.table_name, col.column_name}, values}
      end

    if Map.get(scan_options, :detect_enums, true) do
      pool_size = repo.config()[:pool_size] || 5

      detector_opts =
        [pool_size: pool_size]
        |> maybe_put(:max_concurrency, Map.get(scan_options, :enum_detection_max_concurrency))
        |> maybe_put(:timeout, Map.get(scan_options, :enum_detection_timeout))

      tables_with_counts =
        Enum.map(tables, fn {schema, table, count, _type} -> {schema, table, count} end)

      heuristic_info =
        EnumDetector.detect_heuristic_enums(repo, tables_with_counts, columns, detector_opts)

      {:ok, Map.merge(heuristic_info, pg_enum_info)}
    else
      {:ok, pg_enum_info}
    end
  end

  defp maybe_put(opts, _key, nil), do: opts
  defp maybe_put(opts, key, value), do: Keyword.put(opts, key, value)
end
