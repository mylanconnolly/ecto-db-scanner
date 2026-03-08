defmodule EctoDBScanner.Result.CheckConstraint do
  defstruct [:name, :expression]

  @type t :: %__MODULE__{
          name: String.t(),
          expression: String.t()
        }
end
