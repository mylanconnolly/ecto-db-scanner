defmodule EctoDBScanner.Repo do
  use Ecto.Repo,
    otp_app: :ecto_db_scanner,
    adapter: Ecto.Adapters.Postgres
end
