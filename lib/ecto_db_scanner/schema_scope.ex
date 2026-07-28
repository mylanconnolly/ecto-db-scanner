defmodule EctoDBScanner.SchemaScope do
  @moduledoc """
  Applies schema include/exclude filtering to catalog queries.

  System schemas (`information_schema`, `pg_catalog`, `pg_toast`) are always
  excluded. The `:schemas` scan option restricts the scan to only the listed
  schemas; `:exclude_schemas` skips additional schemas on top of the system
  ones.
  """

  import Ecto.Query

  @system_schemas ["information_schema", "pg_catalog", "pg_toast"]

  @doc """
  The schemas that are always excluded from scans.
  """
  def system_schemas, do: @system_schemas

  @doc """
  Applies schema filters to `query`.

  The query must tag the binding that carries the schema name with
  `as: :schema_scope`; `field_name` is the schema-name field on that binding
  (`:table_schema` for information_schema relations, `:nspname` for
  `pg_namespace`, and so on).
  """
  def apply_scope(query, options, field_name) do
    excluded = @system_schemas ++ (Map.get(options, :exclude_schemas) || [])

    query
    |> where([schema_scope: s], field(s, ^field_name) not in ^excluded)
    |> maybe_include(Map.get(options, :schemas), field_name)
  end

  defp maybe_include(query, nil, _field_name), do: query

  defp maybe_include(query, schemas, field_name) when is_list(schemas) do
    where(query, [schema_scope: s], field(s, ^field_name) in ^schemas)
  end
end
