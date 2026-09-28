defmodule EctoDBScanner.Steps.DetectEnums do
  use Reactor.Step

  alias EctoDBScanner.EnumDetector
  alias EctoDBScanner.RepoRef

  @impl true
  def run(arguments, _context, _step_options) do
    %{repo: repo_ref, tables: tables, columns: columns, pg_enums: pg_enums} = arguments
    scan_options = Map.get(arguments, :options, %{})

    repo = RepoRef.bind(repo_ref)

    pg_enum_info =
      for col <- columns,
          col.data_type == "USER-DEFINED",
          values = Map.get(pg_enums, col.udt_name),
          not is_nil(values),
          into: %{} do
        {{col.table_schema, col.table_name, col.column_name}, values}
      end

    if Map.get(scan_options, :detect_enums, true) do
      detector_opts = detector_opts(scan_options, repo)

      tables_with_counts =
        Enum.map(tables, fn {schema, table, count, _type, _comment} -> {schema, table, count} end)

      heuristic_info =
        EnumDetector.detect_heuristic_enums(repo_ref, tables_with_counts, columns, detector_opts)

      {:ok, Map.merge(heuristic_info, pg_enum_info)}
    else
      {:ok, pg_enum_info}
    end
  end

  @doc false
  # scan/1 passes the pool size of the instance it started; repo.config() only
  # reflects app config, which is right for a conventionally named repo passed
  # straight to the Reactor but not for a scan's own anonymous pool.
  def detector_opts(scan_options, repo) do
    pool_size = Map.get(scan_options, :pool_size) || repo.config()[:pool_size] || 5

    [pool_size: pool_size]
    |> maybe_put(:max_concurrency, Map.get(scan_options, :enum_detection_max_concurrency))
    |> maybe_put(:timeout, Map.get(scan_options, :enum_detection_timeout))
  end

  defp maybe_put(opts, _key, nil), do: opts
  defp maybe_put(opts, key, value), do: Keyword.put(opts, key, value)
end
