defmodule EctoDBScanner.Steps.QueryColumns do
  use Reactor.Step

  import Ecto.Query

  alias EctoDBScanner.InformationSchema
  alias EctoDBScanner.RepoRef
  alias EctoDBScanner.SchemaScope
  alias EctoDBScanner.TypeMapper

  @impl true
  def run(%{repo: repo_ref} = arguments, _context, _options) do
    repo = RepoRef.bind(repo_ref)
    options = Map.get(arguments, :options, %{})

    comments = query_column_comments(repo, options)

    info_schema_columns =
      from(c in InformationSchema.Column,
        as: :schema_scope,
        order_by: [c.table_schema, c.table_name, c.ordinal_position]
      )
      |> SchemaScope.apply_scope(options, :table_schema)
      |> repo.all()
      |> Enum.map(fn col ->
        %{
          table_schema: col.table_schema,
          table_name: col.table_name,
          column_name: col.column_name,
          ordinal_position: col.ordinal_position,
          nullable: col.is_nullable == "YES",
          data_type: col.data_type,
          udt_name: col.udt_name,
          column_default: col.column_default,
          mapped_type: TypeMapper.map_type(col.udt_name),
          comment: Map.get(comments, {col.table_schema, col.table_name, col.column_name})
        }
      end)

    mat_view_columns = query_materialized_view_columns(repo, options, comments)

    {:ok, info_schema_columns ++ mat_view_columns}
  end

  defp query_materialized_view_columns(repo, options, comments) do
    from(a in "pg_attribute",
      prefix: "pg_catalog",
      join: c in "pg_class",
      on: a.attrelid == c.oid,
      prefix: "pg_catalog",
      join: n in "pg_namespace",
      as: :schema_scope,
      on: c.relnamespace == n.oid,
      prefix: "pg_catalog",
      join: t in "pg_type",
      on: a.atttypid == t.oid,
      prefix: "pg_catalog",
      left_join: d in "pg_attrdef",
      on: a.attrelid == d.adrelid and a.attnum == d.adnum,
      prefix: "pg_catalog",
      where: c.relkind == "m",
      where: a.attnum > 0,
      where: not a.attisdropped,
      order_by: [n.nspname, c.relname, a.attnum],
      select: %{
        table_schema: n.nspname,
        table_name: c.relname,
        column_name: a.attname,
        ordinal_position: a.attnum,
        nullable: not a.attnotnull,
        udt_name: t.typname,
        column_default:
          fragment(
            "CASE WHEN ? IS NOT NULL THEN pg_get_expr(?, ?) ELSE NULL END",
            d.adbin,
            d.adbin,
            d.adrelid
          )
      }
    )
    |> SchemaScope.apply_scope(options, :nspname)
    |> repo.all()
    |> Enum.map(fn row ->
      Map.merge(row, %{
        data_type: nil,
        mapped_type: TypeMapper.map_type(row.udt_name),
        comment: Map.get(comments, {row.table_schema, row.table_name, row.column_name})
      })
    end)
  end

  # Column comments come from col_description on pg_attribute;
  # information_schema has no notion of comments.
  defp query_column_comments(repo, options) do
    from(a in "pg_attribute",
      prefix: "pg_catalog",
      join: c in "pg_class",
      on: a.attrelid == c.oid,
      prefix: "pg_catalog",
      join: n in "pg_namespace",
      as: :schema_scope,
      on: c.relnamespace == n.oid,
      prefix: "pg_catalog",
      where: c.relkind in ["r", "m", "v", "p"],
      where: a.attnum > 0,
      where: not a.attisdropped,
      select: {
        n.nspname,
        c.relname,
        a.attname,
        fragment("col_description(?, ?)", a.attrelid, a.attnum)
      }
    )
    |> SchemaScope.apply_scope(options, :nspname)
    |> repo.all()
    |> Enum.reduce(%{}, fn
      {_schema, _table, _column, nil}, acc -> acc
      {schema, table, column, comment}, acc -> Map.put(acc, {schema, table, column}, comment)
    end)
  end
end
