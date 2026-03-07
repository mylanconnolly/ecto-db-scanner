defmodule EctoDBScanner.Steps.QueryPGEnums do
  use Reactor.Step

  alias EctoDBScanner.EnumDetector

  @impl true
  def run(%{repo: repo}, _context, _options) do
    {:ok, EnumDetector.query_pg_enums(repo)}
  end
end
