defmodule EctoDBScanner.EnumDetector do
  @moduledoc """
  Detects enum-like columns via PostgreSQL ENUM types and heuristic analysis.
  """

  import Ecto.Query

  require Logger

  alias EctoDBScanner.RepoRef

  @min_rows 100
  @max_distinct 50
  @max_ratio 0.10

  # Tables larger than this trigger TABLESAMPLE-based distinct counting so we
  # don't scan billion-row tables to evaluate a cardinality heuristic.
  @sample_threshold 100_000
  # Target sample size when sampling. Block-based SYSTEM sampling has high
  # variance, so the realized sample may be larger or smaller.
  @sample_size 100_000

  @default_timeout 60_000

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

  ## Options

    * `:max_concurrency` — number of columns to sample in parallel. Defaults to
      `pool_size - 1` (minimum 1) when `:pool_size` is given, otherwise to the
      system schedulers count.
    * `:pool_size` — repo pool size used to derive `:max_concurrency` when the
      latter is not set explicitly.
    * `:timeout` — per-column sampling timeout in milliseconds. Defaults to
      `60_000`. A column whose sampling exceeds this is dropped from the
      results; it does not abort the rest of the run.

  A column whose sampling query fails (a dropped pool checkout, a table
  removed mid-scan, a permission error) is likewise dropped with a logged
  warning rather than failing the run.
  """
  def detect_heuristic_enums(repo_ref, tables_with_counts, columns, opts \\ []) do
    string_columns =
      for col <- columns,
          col.mapped_type == :string,
          {schema, table, count} <- tables_with_counts,
          schema == col.table_schema and table == col.table_name,
          count >= @min_rows,
          do: {schema, table, col.column_name, count}

    max_concurrency =
      Keyword.get_lazy(opts, :max_concurrency, fn ->
        case Keyword.get(opts, :pool_size) do
          nil -> System.schedulers_online()
          pool_size -> max(pool_size - 1, 1)
        end
      end)

    timeout = Keyword.get(opts, :timeout, @default_timeout)

    string_columns
    |> Task.async_stream(
      fn {schema, table, column, total_rows} ->
        # put_dynamic_repo is process-local, so the bind must happen inside
        # each sampling task, not once in the caller.
        repo = RepoRef.bind(repo_ref)
        check_column(repo, schema, table, column, total_rows)
      end,
      max_concurrency: max_concurrency,
      timeout: timeout,
      on_timeout: :kill_task
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

    key = {schema, table, column}

    with {:ok, %{rows: [[distinct_count, sample_rows]]}} <-
           repo.query(
             "SELECT COUNT(DISTINCT #{quoted_col}), COUNT(*) " <>
               "FROM #{qualified} TABLESAMPLE SYSTEM ($1) WHERE #{quoted_col} IS NOT NULL",
             [percentage]
           ),
         true <- enum_like?(distinct_count, sample_rows),
         {:ok, %{rows: rows}} <-
           repo.query(
             "SELECT DISTINCT #{quoted_col} FROM #{qualified} TABLESAMPLE SYSTEM ($1) " <>
               "WHERE #{quoted_col} IS NOT NULL ORDER BY #{quoted_col} LIMIT 51",
             [percentage]
           ) do
      {key, Enum.map(rows, fn [v] -> v end)}
    else
      false -> {key, nil}
      {:error, error} -> skip_column(key, error)
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
  rescue
    error in [DBConnection.ConnectionError, Postgrex.Error] ->
      skip_column({schema, table, column}, error)
  end

  defp enum_like?(_distinct_count, 0), do: false

  defp enum_like?(distinct_count, sample_rows),
    do: distinct_count <= @max_distinct and distinct_count / sample_rows <= @max_ratio

  defp skip_column({schema, table, column} = key, error) do
    Logger.warning(
      "EctoDBScanner: skipping enum detection for #{schema}.#{table}.#{column}: " <>
        Exception.message(error)
    )

    {key, nil}
  end

  defp sample_percentage(total_rows) do
    pct = @sample_size * 100.0 / total_rows
    pct |> max(0.01) |> min(100.0) |> Float.round(4)
  end

  defp qualify(schema, table), do: ~s|"#{escape(schema)}"."#{escape(table)}"|

  defp quote_ident(name), do: ~s|"#{escape(name)}"|

  defp escape(name), do: String.replace(name, ~s|"|, ~s|""|)
end
