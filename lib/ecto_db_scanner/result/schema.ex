defmodule EctoDBScanner.Result.Schema do
  defstruct [:name, tables: []]

  @type t :: %__MODULE__{
          name: String.t(),
          tables: [EctoDBScanner.Result.Table.t()]
        }
end
