defmodule EctoDBScanner.Result.Column do
  defstruct [
    :name,
    :type,
    :nullable,
    :enum_values,
    :default,
    primary_key: false,
    foreign_key: nil
  ]

  @type foreign_key_ref :: %{
          schema: String.t(),
          table: String.t(),
          column: String.t()
        }

  @type t :: %__MODULE__{
          name: String.t(),
          type: atom() | {:array, atom()} | {:unknown, String.t()},
          nullable: boolean(),
          enum_values: [String.t()] | nil,
          default: String.t() | nil,
          primary_key: boolean(),
          foreign_key: foreign_key_ref() | nil
        }
end
