defmodule EctoDBScanner.TypeMapper do
  @moduledoc """
  Maps PostgreSQL `udt_name` values to generalized Elixir types.
  """

  @integer_types ~w(int2 int4 int8 serial bigserial smallserial)
  @float_types ~w(float4 float8 numeric)
  @string_types ~w(varchar text char bpchar citext name)
  @network_types ~w(inet cidr macaddr macaddr8)
  @json_types ~w(json jsonb)

  @spec map_type(String.t()) :: atom() | {:array, atom()} | {:unknown, String.t()}
  def map_type("_" <> inner) do
    {:array, map_type(inner)}
  end

  def map_type(udt_name) when udt_name in @integer_types, do: :integer
  def map_type(udt_name) when udt_name in @float_types, do: :float
  def map_type("bool"), do: :boolean
  def map_type(udt_name) when udt_name in @string_types, do: :string
  def map_type("date"), do: :date
  def map_type(udt_name) when udt_name in ~w(time timetz), do: :time
  def map_type("timestamp"), do: :naive_datetime
  def map_type("timestamptz"), do: :datetime
  def map_type("uuid"), do: :uuid
  def map_type(udt_name) when udt_name in @json_types, do: :map
  def map_type("bytea"), do: :binary
  def map_type(udt_name) when udt_name in @network_types, do: :string
  def map_type(udt_name), do: {:unknown, udt_name}
end
