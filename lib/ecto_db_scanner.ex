defmodule EctoDBScanner do
  @moduledoc """
  A PostgreSQL database scanner that discovers structure, maps types, and detects enums.
  """

  @default_pool_size 5

  @scan_opts [
    :analyze,
    :detect_enums,
    :enum_detection_timeout,
    :enum_detection_max_concurrency
  ]

  @doc """
  Scans a PostgreSQL database and returns its structure.

  Accepts connection params as a keyword list:

      EctoDBScanner.scan(
        hostname: "localhost",
        username: "postgres",
        password: "postgres",
        database: "my_db",
        port: 5432
      )

  ## Options

    * `:analyze` (boolean, default `true`) — Runs `ANALYZE` against the target
      database before scanning so planner statistics (notably
      `pg_class.reltuples`, used for row counts and enum detection sampling)
      are fresh. On large databases this may take a while; set to `false` if
      stats are already current or the connecting role lacks permission.

    * `:detect_enums` (boolean, default `true`) — Runs the cardinality-based
      heuristic that samples string columns to detect enum-like sets of
      values. Set to `false` to skip detection on databases where even
      `TABLESAMPLE`-bounded sampling is too slow; PostgreSQL `ENUM`-typed
      columns are still detected via catalog lookup.

    * `:enum_detection_timeout` (integer, default `60_000`) — Per-column
      sampling timeout in milliseconds for heuristic enum detection. A column
      that exceeds it is silently dropped from the results, the rest of the
      scan continues.

    * `:enum_detection_max_concurrency` (integer) — Number of columns to
      sample concurrently. Defaults to `pool_size - 1` (minimum 1) so the
      connection pool is not saturated by the scan itself.

  All other options are passed through to the underlying repo connection.

  Returns `{:ok, %EctoDBScanner.Result.Database{}}` or `{:error, reason}`.
  """
  def scan(opts) when is_list(opts) do
    {scan_opts, repo_opts} = Keyword.split(opts, @scan_opts)

    repo_config =
      Keyword.merge(
        [pool_size: @default_pool_size],
        repo_opts
      )

    {:ok, repo_pid} = EctoDBScanner.Repo.start_link(repo_config)

    try do
      if Keyword.get(scan_opts, :analyze, true) do
        Ecto.Adapters.SQL.query!(EctoDBScanner.Repo, "ANALYZE", [], timeout: :infinity)
      end

      reactor_options = %{
        detect_enums: Keyword.get(scan_opts, :detect_enums, true),
        enum_detection_timeout: Keyword.get(scan_opts, :enum_detection_timeout),
        enum_detection_max_concurrency: Keyword.get(scan_opts, :enum_detection_max_concurrency)
      }

      Reactor.run(EctoDBScanner.Scanner, %{
        repo: EctoDBScanner.Repo,
        options: reactor_options
      })
    after
      Supervisor.stop(repo_pid)
    end
  end
end
