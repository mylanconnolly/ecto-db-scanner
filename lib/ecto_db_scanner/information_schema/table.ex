defmodule EctoDBScanner.InformationSchema.Table do
  use Ecto.Schema

  @schema_prefix "information_schema"
  @primary_key false

  schema "tables" do
    field :table_schema, :string
    field :table_name, :string
    field :table_type, :string
  end
end
