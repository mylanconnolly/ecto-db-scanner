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

  Returns `{:ok, %EctoDBScanner.Result.Database{}}` or `{:error, reason}`.
  """
  def scan(opts) when is_list(opts) do
    repo_config =
      Keyword.merge(
        [pool_size: @default_pool_size],
        opts
      )

    {:ok, repo_pid} = EctoDBScanner.Repo.start_link(repo_config)

    try do
      Reactor.run(EctoDBScanner.Scanner, %{repo: EctoDBScanner.Repo})
    after
      Supervisor.stop(repo_pid)
    end
  end
end
