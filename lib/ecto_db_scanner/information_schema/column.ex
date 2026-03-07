defmodule EctoDBScanner.InformationSchema.Column do
  use Ecto.Schema

  @schema_prefix "information_schema"
  @primary_key false

  schema "columns" do
    field :table_schema, :string
    field :table_name, :string
    field :column_name, :string
    field :ordinal_position, :integer
    field :is_nullable, :string
    field :data_type, :string
    field :udt_name, :string
    field :column_default, :string
  end
end
