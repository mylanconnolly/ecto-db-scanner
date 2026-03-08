defmodule EctoDBScanner.Result.Table do
  defstruct [
    :name,
    :type,
    :row_count,
    :size_bytes,
    :index_size_bytes,
    :total_size_bytes,
    columns: [],
    indexes: [],
    check_constraints: [],
    unique_constraints: []
  ]

  @type t :: %__MODULE__{
          name: String.t(),
          type: :table | :view | :materialized_view,
          row_count: integer(),
          size_bytes: integer(),
          index_size_bytes: integer(),
          total_size_bytes: integer(),
          columns: [EctoDBScanner.Result.Column.t()],
          indexes: [EctoDBScanner.Result.Index.t()],
          check_constraints: [EctoDBScanner.Result.CheckConstraint.t()],
          unique_constraints: [EctoDBScanner.Result.UniqueConstraint.t()]
        }
end
