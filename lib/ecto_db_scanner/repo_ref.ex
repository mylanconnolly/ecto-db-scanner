defmodule EctoDBScanner.RepoRef do
  @moduledoc """
  A reference to a running repo instance: the repo module plus the pid of a
  dynamically started (unnamed) instance.

  `EctoDBScanner.scan/1` starts `EctoDBScanner.Repo` with `name: nil` so that
  concurrent scans never collide on a registered process name. Because
  `Ecto.Repo.put_dynamic_repo/1` is process-local, every process that runs
  queries — each Reactor step as well as any task it spawns — must call
  `bind/1` before making module-style repo calls (`repo.all/1`, etc.).
  """

  defstruct [:module, :pid]

  @type t :: %__MODULE__{module: module(), pid: pid() | nil}

  @doc """
  Builds a reference to the repo `module` backed by the instance at `pid`.
  """
  def new(module, pid \\ nil), do: %__MODULE__{module: module, pid: pid}

  @doc """
  Binds the referenced repo instance to the current process and returns the
  repo module, ready for module-style calls.

  A bare repo module is also accepted (and returned as-is) for callers that
  run the scanner against a conventionally named repo, such as the test
  suite's `TestRepo`.
  """
  def bind(%__MODULE__{module: module, pid: nil}), do: module

  def bind(%__MODULE__{module: module, pid: pid}) do
    module.put_dynamic_repo(pid)
    module
  end

  def bind(module) when is_atom(module), do: module
end
