defmodule EctoDBScanner.TestRepo.Migrations.CreateTestTables do
  use Ecto.Migration

  def up do
    # Create custom schema
    execute("CREATE SCHEMA IF NOT EXISTS custom_schema")

    # Create PG ENUM type
    execute("CREATE TYPE mood AS ENUM ('happy', 'sad', 'neutral', 'excited')")

    # 1. users - mixed types, enum-like status column
    create table(:users) do
      add(:name, :text, null: false)
      add(:email, :text, null: false)
      add(:status, :varchar, null: false)
      add(:inserted_at, :timestamptz, null: false, default: fragment("now()"))
      add(:updated_at, :timestamptz, null: false, default: fragment("now()"))
    end

    # 2. posts - nullable columns, text content, jsonb, FK to users
    create table(:posts) do
      add(:title, :text, null: false)
      add(:body, :text)
      add(:user_id, references(:users), null: false)
      add(:metadata, :jsonb)
      add(:published, :boolean, default: false)
      add(:inserted_at, :timestamptz, null: false, default: fragment("now()"))
    end

    # 3. comments - FK to both posts and users (multiple FKs on one table)
    create table(:comments) do
      add(:body, :text, null: false)
      add(:post_id, references(:posts), null: false)
      add(:user_id, references(:users), null: false)
      add(:inserted_at, :timestamptz, null: false, default: fragment("now()"))
    end

    # 4. products - numeric types, boolean, uuid PK
    create table(:products, primary_key: false) do
      add(:id, :uuid, primary_key: true, default: fragment("gen_random_uuid()"))
      add(:name, :text, null: false)
      add(:price, :numeric, null: false)
      add(:quantity, :integer, null: false, default: 0)
      add(:active, :boolean, null: false, default: true)
    end

    # 5. events - date/time types
    create table(:events) do
      add(:name, :text, null: false)
      add(:event_date, :date, null: false)
      add(:start_time, :time)
      add(:naive_ts, :naive_datetime)
      add(:precise_ts, :timestamptz)
    end

    # 6. network_info - network types
    create table(:network_info) do
      add(:ip_address, :inet)
      add(:network, :cidr)
      add(:mac, :macaddr)
    end

    # 7. with_arrays - array columns
    create table(:with_arrays) do
      add(:tags, {:array, :text})
      add(:scores, {:array, :integer})
    end

    # 8. with_pg_enum - PostgreSQL ENUM type column
    create table(:with_pg_enum) do
      add(:current_mood, :mood, null: false)
      add(:description, :text)
    end

    # 9. custom_schema.items - non-public schema with FK to public.users
    create table(:items, prefix: "custom_schema") do
      add(:name, :text, null: false)
      add(:category, :varchar, null: false)
      add(:weight, :float)
    end

    execute("""
    ALTER TABLE custom_schema.items
    ADD COLUMN created_by_id bigint REFERENCES public.users(id)
    """)

    # 10. binary_data - bytea column
    create table(:binary_data) do
      add(:payload, :binary)
      add(:label, :text)
    end

    # 11. A regular VIEW
    execute("""
    CREATE VIEW public.active_users AS
    SELECT id, name, email, inserted_at
    FROM public.users
    WHERE status = 'active'
    """)

    # 12. A MATERIALIZED VIEW
    execute("""
    CREATE MATERIALIZED VIEW public.user_post_counts AS
    SELECT u.id AS user_id, u.name, COUNT(p.id) AS post_count
    FROM public.users u
    LEFT JOIN public.posts p ON p.user_id = u.id
    GROUP BY u.id, u.name
    """)

    # 13. Indexes for testing index discovery
    create(unique_index(:users, [:email]))
    create(index(:posts, [:inserted_at]))
    create(index(:comments, [:post_id, :user_id]))

    execute("CREATE INDEX with_arrays_tags_gin ON with_arrays USING gin (tags)")

    # 14. Check constraints
    execute("ALTER TABLE products ADD CONSTRAINT products_price_positive CHECK (price > 0)")

    execute(
      "ALTER TABLE products ADD CONSTRAINT products_quantity_non_negative CHECK (quantity >= 0)"
    )

    # 15. Unique constraints (distinct from unique indexes - these create pg_constraint entries)
    execute("ALTER TABLE events ADD CONSTRAINT events_name_unique UNIQUE (name)")

    execute("ALTER TABLE products ADD CONSTRAINT products_name_unique UNIQUE (name)")
  end

  def down do
    execute("ALTER TABLE products DROP CONSTRAINT IF EXISTS products_name_unique")
    execute("ALTER TABLE events DROP CONSTRAINT IF EXISTS events_name_unique")
    execute("ALTER TABLE products DROP CONSTRAINT IF EXISTS products_quantity_non_negative")
    execute("ALTER TABLE products DROP CONSTRAINT IF EXISTS products_price_positive")
    execute("DROP INDEX IF EXISTS with_arrays_tags_gin")
    drop_if_exists(index(:comments, [:post_id, :user_id]))
    drop_if_exists(index(:posts, [:inserted_at]))
    drop_if_exists(unique_index(:users, [:email]))
    execute("DROP MATERIALIZED VIEW IF EXISTS public.user_post_counts")
    execute("DROP VIEW IF EXISTS public.active_users")
    drop(table(:binary_data))
    execute("ALTER TABLE custom_schema.items DROP COLUMN IF EXISTS created_by_id")
    drop(table(:items, prefix: "custom_schema"))
    drop(table(:with_pg_enum))
    drop(table(:with_arrays))
    drop(table(:network_info))
    drop(table(:events))
    drop(table(:products))
    drop(table(:comments))
    drop(table(:posts))
    drop(table(:users))
    execute("DROP TYPE IF EXISTS mood")
    execute("DROP SCHEMA IF EXISTS custom_schema CASCADE")
  end
end
