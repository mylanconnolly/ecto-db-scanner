defmodule EctoDBScanner.Result.UniqueConstraint do
  defstruct [:name, columns: []]

  @type t :: %__MODULE__{
          name: String.t(),
          columns: [String.t()]
        }
end
