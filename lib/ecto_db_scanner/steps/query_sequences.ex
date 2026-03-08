defmodule EctoDBScanner.Steps.QuerySequences do
  use Reactor.Step

  import Ecto.Query

  @system_schemas ["information_schema", "pg_catalog", "pg_toast"]

  @impl true
  def run(%{repo: repo}, _context, _options) do
    sequences = query_sequences(repo)

    {:ok, sequences}
  end

  defp query_sequences(repo) do
    from(c in "pg_class",
      prefix: "pg_catalog",
      join: n in "pg_namespace",
      on: c.relnamespace == n.oid,
      prefix: "pg_catalog",
      left_join: d in "pg_depend",
      on: d.objid == c.oid and d.deptype == "a",
      prefix: "pg_catalog",
      left_join: ac in "pg_class",
      on: d.refobjid == ac.oid,
      prefix: "pg_catalog",
      left_join: att in "pg_attribute",
      on: att.attrelid == ac.oid and att.attnum == d.refobjsubid,
      prefix: "pg_catalog",
      left_join: an in "pg_namespace",
      on: ac.relnamespace == an.oid,
      prefix: "pg_catalog",
      where: c.relkind == "S",
      where: n.nspname not in @system_schemas,
      select: {
        n.nspname,
        c.relname,
        fragment("pg_sequence_last_value(?)", c.oid),
        fragment(
          "CASE WHEN ? IS NOT NULL THEN ? || '.' || ? || '.' || ? ELSE NULL END",
          att.attname,
          an.nspname,
          ac.relname,
          att.attname
        )
      },
      order_by: [n.nspname, c.relname]
    )
    |> repo.all()
    |> Enum.group_by(
      fn {schema, _, _, _} -> schema end,
      fn {_, name, last_value, owned_by} ->
        %{name: name, current_value: last_value, owned_by: owned_by}
      end
    )
  end
end
