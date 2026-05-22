defmodule EctoDBScanner.EnumDetector do
  @moduledoc """
  Detects enum-like columns via PostgreSQL ENUM types and heuristic analysis.
  """

  import Ecto.Query

  @min_rows 100
  @max_distinct 50
  @max_ratio 0.10

  # Tables larger than this trigger TABLESAMPLE-based distinct counting so we
  # don't scan billion-row tables to evaluate a cardinality heuristic.
  @sample_threshold 100_000
  # Target sample size when sampling. Block-based SYSTEM sampling has high
  # variance, so the realized sample may be larger or smaller.
  @sample_size 100_000

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

  defp check_column(repo, schema, table, column, total_rows)
       when total_rows > @sample_threshold do
    percentage = sample_percentage(total_rows)
    qualified = qualify(schema, table)
    quoted_col = quote_ident(column)

    {:ok, %{rows: [[distinct_count, sample_rows]]}} =
      Ecto.Adapters.SQL.query(
        repo,
        "SELECT COUNT(DISTINCT #{quoted_col}), COUNT(*) " <>
          "FROM #{qualified} TABLESAMPLE SYSTEM ($1) WHERE #{quoted_col} IS NOT NULL",
        [percentage]
      )

    sample_ratio = if sample_rows > 0, do: distinct_count / sample_rows, else: 1.0

    if distinct_count <= @max_distinct and sample_ratio <= @max_ratio do
      {:ok, %{rows: rows}} =
        Ecto.Adapters.SQL.query(
          repo,
          "SELECT DISTINCT #{quoted_col} FROM #{qualified} TABLESAMPLE SYSTEM ($1) " <>
            "WHERE #{quoted_col} IS NOT NULL ORDER BY #{quoted_col} LIMIT 51",
          [percentage]
        )

      values = Enum.map(rows, fn [v] -> v end)
      {{schema, table, column}, values}
    else
      {{schema, table, column}, nil}
    end
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

  defp sample_percentage(total_rows) do
    pct = @sample_size * 100.0 / total_rows
    pct |> max(0.01) |> min(100.0) |> Float.round(4)
  end

  defp qualify(schema, table), do: ~s|"#{escape(schema)}"."#{escape(table)}"|

  defp quote_ident(name), do: ~s|"#{escape(name)}"|

  defp escape(name), do: String.replace(name, ~s|"|, ~s|""|)
end
