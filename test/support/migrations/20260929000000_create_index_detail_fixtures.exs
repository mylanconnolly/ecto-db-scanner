defmodule EctoDBScanner.TestRepo.Migrations.CreateIndexDetailFixtures do
  use Ecto.Migration

  # Index shapes whose details a column list alone can't describe.
  def change do
    execute(
      "CREATE INDEX posts_unpublished_inserted_at ON posts (inserted_at) WHERE published = false",
      "DROP INDEX posts_unpublished_inserted_at"
    )

    execute(
      "CREATE INDEX users_lower_email ON users (lower(email))",
      "DROP INDEX users_lower_email"
    )

    execute(
      "CREATE INDEX comments_post_id_covering ON comments (post_id) INCLUDE (body)",
      "DROP INDEX comments_post_id_covering"
    )
  end
end
