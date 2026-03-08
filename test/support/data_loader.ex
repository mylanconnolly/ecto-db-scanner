defmodule EctoDBScanner.DataLoader do
  @moduledoc """
  Seeds test data for integration tests.
  """

  alias EctoDBScanner.TestRepo

  @statuses ["active", "inactive", "pending"]
  @moods ["happy", "sad", "neutral", "excited"]
  @categories ["electronics", "books", "clothing"]

  def seed! do
    seed_users()
    seed_posts()
    seed_comments()
    seed_products()
    seed_events()
    seed_network_info()
    seed_with_arrays()
    seed_with_pg_enum()
    seed_custom_schema_items()
    seed_binary_data()
    refresh_materialized_views()
    analyze_tables()
  end

  defp seed_users do
    rows =
      for i <- 1..250 do
        status = Enum.at(@statuses, rem(i, length(@statuses)))

        [
          name: "User #{i}",
          email: "user#{i}@example.com",
          status: status,
          inserted_at: DateTime.utc_now(),
          updated_at: DateTime.utc_now()
        ]
      end

    TestRepo.insert_all("users", rows)
  end

  defp seed_posts do
    rows =
      for i <- 1..250 do
        [
          title: "Post #{i}",
          body: "Body content for post #{i} with unique text #{:rand.uniform(100_000)}",
          user_id: rem(i - 1, 250) + 1,
          metadata: Jason.encode!(%{views: i * 10}),
          published: rem(i, 2) == 0,
          inserted_at: DateTime.utc_now()
        ]
      end

    TestRepo.insert_all("posts", rows)
  end

  defp seed_comments do
    rows =
      for i <- 1..200 do
        [
          body: "Comment #{i}",
          post_id: rem(i - 1, 250) + 1,
          user_id: rem(i - 1, 250) + 1,
          inserted_at: DateTime.utc_now()
        ]
      end

    TestRepo.insert_all("comments", rows)
  end

  defp seed_products do
    rows =
      for i <- 1..250 do
        [
          id: Ecto.UUID.bingenerate(),
          name: "Product #{i}",
          price: Decimal.new("#{i}.99"),
          quantity: i * 2,
          active: rem(i, 5) != 0
        ]
      end

    TestRepo.insert_all("products", rows)
  end

  defp seed_events do
    rows =
      for i <- 1..200 do
        [
          name: "Event #{i}",
          event_date: Date.add(Date.utc_today(), i),
          start_time: Time.new!(rem(i, 24), rem(i * 7, 60), 0),
          naive_ts: NaiveDateTime.utc_now(),
          precise_ts: DateTime.utc_now()
        ]
      end

    TestRepo.insert_all("events", rows)
  end

  defp seed_network_info do
    rows =
      for i <- 1..200 do
        [
          ip_address: %Postgrex.INET{address: {192, 168, 1, rem(i, 256)}},
          network: %Postgrex.INET{address: {10, 0, 0, 0}, netmask: 24},
          mac: %Postgrex.MACADDR{address: {0, 1, 2, 3, 4, rem(i, 256)}}
        ]
      end

    TestRepo.insert_all("network_info", rows)
  end

  defp seed_with_arrays do
    rows =
      for i <- 1..200 do
        [
          tags: ["tag#{rem(i, 10)}", "common"],
          scores: [i, i * 2, i * 3]
        ]
      end

    TestRepo.insert_all("with_arrays", rows)
  end

  defp seed_with_pg_enum do
    rows =
      for i <- 1..200 do
        mood = Enum.at(@moods, rem(i, length(@moods)))
        [current_mood: mood, description: "Entry #{i}"]
      end

    # Use raw SQL because Ecto doesn't know about custom enum types
    for row <- rows do
      Ecto.Adapters.SQL.query!(
        TestRepo,
        "INSERT INTO with_pg_enum (current_mood, description) VALUES ($1::mood, $2)",
        [row[:current_mood], row[:description]]
      )
    end
  end

  defp seed_custom_schema_items do
    rows =
      for i <- 1..200 do
        category = Enum.at(@categories, rem(i, length(@categories)))
        [name: "Item #{i}", category: category, weight: i * 0.5]
      end

    TestRepo.insert_all("items", rows, prefix: "custom_schema")
  end

  defp seed_binary_data do
    rows =
      for i <- 1..200 do
        [payload: :crypto.strong_rand_bytes(16), label: "Binary #{i}"]
      end

    TestRepo.insert_all("binary_data", rows)
  end

  defp refresh_materialized_views do
    Ecto.Adapters.SQL.query!(TestRepo, "REFRESH MATERIALIZED VIEW public.user_post_counts", [])
  end

  defp analyze_tables do
    Ecto.Adapters.SQL.query!(TestRepo, "ANALYZE", [])
  end
end
