defmodule EctoDBScanner.EnumDetector do
  @moduledoc """
  Detects enum-like columns via PostgreSQL ENUM types and heuristic analysis.
  """

  import Ecto.Query

  @min_rows 100
  @max_distinct 50
  @max_ratio 0.10

  @doc """
  Queries pg_type/pg_enum catalogs for all defined PostgreSQL ENUM types.
  Returns `%{"type_name" => ["val1", "val2", ...]}`.
  """
  def query_pg_enums(repo) do
    from(t in "pg_type",
      prefix: "pg_catalog",
      join: e in "pg_enum",
      on: t.oid == e.enumtypid,
      prefix: "pg_catalog",
      order_by: [t.typname, e.enumsortorder],
      select: {t.typname, e.enumlabel}
    )
    |> repo.all()
    |> Enum.group_by(fn {name, _} -> name end, fn {_, label} -> label end)
  end

  @doc """
  Detects enum-like string columns using cardinality heuristics.
  Returns `%{{schema, table, column} => ["val1", "val2", ...]}`.
  """
  def detect_heuristic_enums(repo, tables_with_counts, columns, pool_size) do
    string_columns =
      for col <- columns,
          col.mapped_type == :string,
          {schema, table, count} <- tables_with_counts,
          schema == col.table_schema and table == col.table_name,
          count >= @min_rows,
          do: {schema, table, col.column_name, count}

    max_concurrency = max(pool_size - 1, 1)

    string_columns
    |> Task.async_stream(
      fn {schema, table, column, total_rows} ->
        check_column(repo, schema, table, column, total_rows)
      end,
      max_concurrency: max_concurrency,
      timeout: 30_000
    )
    |> Enum.reduce(%{}, fn
      {:ok, {key, values}}, acc when not is_nil(values) -> Map.put(acc, key, values)
      _, acc -> acc
    end)
  end

  defp check_column(repo, schema, table, column, total_rows) do
    distinct_count =
      from(t in table,
        prefix: ^schema,
        where: not is_nil(field(t, ^column)),
        select: count(field(t, ^column), :distinct)
      )
      |> repo.one()

    if distinct_count <= @max_distinct and distinct_count / total_rows <= @max_ratio do
      values =
        from(t in table,
          prefix: ^schema,
          where: not is_nil(field(t, ^column)),
          distinct: true,
          order_by: field(t, ^column),
          limit: 51,
          select: field(t, ^column)
        )
        |> repo.all()

      {{schema, table, column}, values}
    else
      {{schema, table, column}, nil}
    end
  end
end
