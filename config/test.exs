import Config

config :logger, level: :warning

config :ecto_db_scanner, EctoDBScanner.TestRepo,
  hostname: "localhost",
  username: "postgres",
  password: "postgres",
  database: "ecto_db_scanner_test",
  port: 5432,
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: 10
