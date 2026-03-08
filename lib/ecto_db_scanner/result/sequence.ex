defmodule EctoDBScanner.Result.Sequence do
  defstruct [:name, :current_value, :owned_by]

  @type t :: %__MODULE__{
          name: String.t(),
          current_value: integer(),
          owned_by: String.t() | nil
        }
end
