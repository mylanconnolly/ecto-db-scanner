defmodule EctoDBScanner.Result.Index do
  @moduledoc """
  A secondary index (primary-key indexes are not reported; the primary key
  is on the columns).

    * `columns` — key columns in order; expression keys appear as their
      expression (`lower(email)`).
    * `include` — non-key `INCLUDE` columns.
    * `predicate` — the `WHERE` clause of a partial index, or `nil`.
    * `definition` — the full `CREATE INDEX` statement (`pg_get_indexdef`).
    * `size_bytes` — on-disk size of the index.
  """

  defstruct [
    :name,
    :type,
    :unique,
    :predicate,
    :definition,
    :size_bytes,
    columns: [],
    include: []
  ]

  @type t :: %__MODULE__{
          name: String.t(),
          type: String.t(),
          unique: boolean(),
          columns: [String.t()],
          include: [String.t()],
          predicate: String.t() | nil,
          definition: String.t() | nil,
          size_bytes: non_neg_integer() | nil
        }
end
