defmodule EctoDBScanner do
  @moduledoc """
  A PostgreSQL database scanner that discovers structure, maps types, and detects enums.
  """

  @default_pool_size 5

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

  All other options are passed through to the underlying repo connection.

  Returns `{:ok, %EctoDBScanner.Result.Database{}}` or `{:error, reason}`.
  """
  def scan(opts) when is_list(opts) do
    {analyze?, repo_opts} = Keyword.pop(opts, :analyze, true)

    repo_config =
      Keyword.merge(
        [pool_size: @default_pool_size],
        repo_opts
      )

    {:ok, repo_pid} = EctoDBScanner.Repo.start_link(repo_config)

    try do
      if analyze? do
        Ecto.Adapters.SQL.query!(EctoDBScanner.Repo, "ANALYZE", [], timeout: :infinity)
      end

      Reactor.run(EctoDBScanner.Scanner, %{repo: EctoDBScanner.Repo})
    after
      Supervisor.stop(repo_pid)
    end
  end
end
