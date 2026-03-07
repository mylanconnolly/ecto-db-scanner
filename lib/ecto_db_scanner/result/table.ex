defmodule EctoDBScanner.Result.Table do
  defstruct [:name, :type, columns: []]

  @type t :: %__MODULE__{
          name: String.t(),
          type: :table | :view | :materialized_view,
          columns: [EctoDBScanner.Result.Column.t()]
        }
end
