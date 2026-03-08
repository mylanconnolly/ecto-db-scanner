defmodule EctoDBScanner.Result.Schema do
  defstruct [:name, tables: [], sequences: []]

  @type t :: %__MODULE__{
          name: String.t(),
          tables: [EctoDBScanner.Result.Table.t()],
          sequences: [EctoDBScanner.Result.Sequence.t()]
        }
end
