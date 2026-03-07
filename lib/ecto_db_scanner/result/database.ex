defmodule EctoDBScanner.Result.Database do
  defstruct schemas: []

  @type t :: %__MODULE__{
          schemas: [EctoDBScanner.Result.Schema.t()]
        }
end
