defmodule EctoDBScanner.Steps.QueryIndexes do
  use Reactor.Step

  import Ecto.Query

  alias EctoDBScanner.RepoRef
  alias EctoDBScanner.SchemaScope

  @impl true
  def run(%{repo: repo_ref} = arguments, _context, _options) do
    repo = RepoRef.bind(repo_ref)
    options = Map.get(arguments, :options, %{})

    indexes = query_indexes(repo, options)

    {:ok, indexes}
  end

  defp query_indexes(repo, options) do
    from(i in "pg_index",
      prefix: "pg_catalog",
      join: ic in "pg_class",
      on: i.indexrelid == ic.oid,
      prefix: "pg_catalog",
      join: tc in "pg_class",
      on: i.indrelid == tc.oid,
      prefix: "pg_catalog",
      join: n in "pg_namespace",
      as: :schema_scope,
      on: tc.relnamespace == n.oid,
      prefix: "pg_catalog",
      join: am in "pg_am",
      on: ic.relam == am.oid,
      prefix: "pg_catalog",
      where: not i.indisprimary,
      select: {
        n.nspname,
        tc.relname,
        ic.relname,
        am.amname,
        i.indisunique,
        fragment("pg_get_indexdef(?)", i.indexrelid)
      }
    )
    |> SchemaScope.apply_scope(options, :nspname)
    |> repo.all()
    |> Enum.group_by(
      fn {schema, table, _, _, _, _} -> {schema, table} end,
      fn {_, _, index_name, am_name, unique, indexdef} ->
        %{
          name: index_name,
          type: am_name,
          unique: unique,
          columns: parse_index_columns(indexdef)
        }
      end
    )
  end

  defp parse_index_columns(indexdef) do
    case Regex.run(~r/\((.+)\)$/, indexdef) do
      [_, columns_str] ->
        columns_str
        |> String.split(",")
        |> Enum.map(&String.trim/1)

      _ ->
        []
    end
  end
end
