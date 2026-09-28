defmodule EctoDBScanner do
  @moduledoc """
  A PostgreSQL database scanner that discovers structure, maps types, and detects enums.
  """

  alias EctoDBScanner.RepoRef

  @default_pool_size 5

  @scan_opts [
    :analyze,
    :detect_enums,
    :enum_detection_timeout,
    :enum_detection_max_concurrency,
    :schemas,
    :exclude_schemas
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

  Scans are safe to run concurrently: each call starts its own anonymous repo
  instance, so multiple databases (or the same database) can be scanned at the
  same time from a single node.

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
      that exceeds it, or whose sampling query fails (e.g. a dropped pool
      checkout or a table removed mid-scan), is dropped from the results with
      a logged warning; the rest of the scan continues.

    * `:enum_detection_max_concurrency` (integer) — Number of columns to
      sample concurrently. Defaults to `pool_size - 1` (minimum 1), derived
      from the `:pool_size` given to this scan (default 5). Sampling runs after
      the other catalog queries, so it has the pool to itself.

    * `:schemas` (list of strings) — When present, **only** these schemas are
      scanned. Filtering happens at the query level, so tables, columns,
      constraints, sizes, indexes, sequences, and enum detection sampling all
      skip everything outside the listed schemas.

    * `:exclude_schemas` (list of strings) — Schemas to skip, in addition to
      the always-excluded system schemas (`information_schema`, `pg_catalog`,
      `pg_toast`). Applied at the query level like `:schemas`.

  All other options are passed through to the underlying repo connection.

  Returns `{:ok, %EctoDBScanner.Result.Database{}}` or `{:error, reason}`.
  """
  def scan(opts) when is_list(opts) do
    {scan_opts, repo_opts} = Keyword.split(opts, @scan_opts)

    repo_config =
      [pool_size: @default_pool_size]
      |> Keyword.merge(repo_opts)
      # Anonymous instance: concurrent scans must not collide on a registered
      # process name, so every scan starts its own unnamed repo.
      |> Keyword.put(:name, nil)

    {:ok, repo_pid} = EctoDBScanner.Repo.start_link(repo_config)
    repo_ref = RepoRef.new(EctoDBScanner.Repo, repo_pid)

    try do
      if Keyword.get(scan_opts, :analyze, true) do
        # The repo module's own query!/3 (rather than Ecto.Adapters.SQL) so the
        # call is routed to the dynamic instance bound to this process.
        repo = RepoRef.bind(repo_ref)
        repo.query!("ANALYZE", [], timeout: :infinity)
      end

      reactor_options = %{
        detect_enums: Keyword.get(scan_opts, :detect_enums, true),
        enum_detection_timeout: Keyword.get(scan_opts, :enum_detection_timeout),
        enum_detection_max_concurrency: Keyword.get(scan_opts, :enum_detection_max_concurrency),
        pool_size: repo_config[:pool_size],
        schemas: Keyword.get(scan_opts, :schemas),
        exclude_schemas: Keyword.get(scan_opts, :exclude_schemas)
      }

      Reactor.run(EctoDBScanner.Scanner, %{
        repo: repo_ref,
        options: reactor_options
      })
    after
      Supervisor.stop(repo_pid)
    end
  end
end
