defmodule EctoDBScanner.Result.Database do
  defstruct [:size_bytes, schemas: []]

  @type t :: %__MODULE__{
          size_bytes: integer(),
          schemas: [EctoDBScanner.Result.Schema.t()]
        }
end
