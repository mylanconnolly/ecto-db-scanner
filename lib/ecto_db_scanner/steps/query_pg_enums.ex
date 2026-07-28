defmodule EctoDBScanner.Steps.QueryPGEnums do
  use Reactor.Step

  alias EctoDBScanner.EnumDetector
  alias EctoDBScanner.RepoRef

  # Intentionally not schema-scoped: enum *types* can live in one schema while
  # being used by columns in another, and the column queries are already
  # filtered — an unfiltered type catalog lookup is cheap and keeps enum
  # values resolvable for cross-schema type usage.
  @impl true
  def run(%{repo: repo_ref}, _context, _options) do
    repo = RepoRef.bind(repo_ref)
    {:ok, EnumDetector.query_pg_enums(repo)}
  end
end
