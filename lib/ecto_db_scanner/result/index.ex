defmodule EctoDBScanner.Result.Index do
  defstruct [
    :name,
    :type,
    :unique,
    columns: []
  ]

  @type t :: %__MODULE__{
          name: String.t(),
          type: String.t(),
          unique: boolean(),
          columns: [String.t()]
        }
end
