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
      select: %{
        schema: n.nspname,
        table: tc.relname,
        name: ic.relname,
        type: am.amname,
        unique: i.indisunique,
        # Key columns (and expressions) straight from the catalog, in order;
        # INCLUDE columns follow the keys in indkey.
        columns:
          fragment(
            "ARRAY(SELECT pg_get_indexdef(?, k, true) FROM generate_series(1, ?) AS k)",
            i.indexrelid,
            i.indnkeyatts
          ),
        include:
          fragment(
            "ARRAY(SELECT pg_get_indexdef(?, k, true) FROM generate_series(? + 1, ?) AS k)",
            i.indexrelid,
            i.indnkeyatts,
            i.indnatts
          ),
        predicate: fragment("pg_get_expr(?, ?, true)", i.indpred, i.indrelid),
        definition: fragment("pg_get_indexdef(?)", i.indexrelid),
        size_bytes: fragment("pg_relation_size(?)", i.indexrelid)
      }
    )
    |> SchemaScope.apply_scope(options, :nspname)
    |> repo.all()
    |> Enum.group_by(
      fn index -> {index.schema, index.table} end,
      fn index -> Map.drop(index, [:schema, :table]) end
    )
  end
end
