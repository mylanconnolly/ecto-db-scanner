ExUnit.start()

# Start the test repo
{:ok, _} = EctoDBScanner.TestRepo.start_link()

# Run migrations
migrations_path = Path.join([__DIR__, "support", "migrations"])

Ecto.Migrator.run(
  EctoDBScanner.TestRepo,
  migrations_path,
  :up,
  all: true,
  log: false
)

# Seed test data
EctoDBScanner.DataLoader.seed!()
