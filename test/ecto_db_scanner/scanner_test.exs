defmodule EctoDBScanner.ScannerTest do
  use ExUnit.Case

  alias EctoDBScanner.Result

  setup_all do
    {:ok, result} = Reactor.run(EctoDBScanner.Scanner, %{repo: EctoDBScanner.TestRepo})
    %{db: result}
  end

  defp find_schema(db, name) do
    Enum.find(db.schemas, &(&1.name == name))
  end

  defp find_table(schema, name) do
    Enum.find(schema.tables, &(&1.name == name))
  end

  defp find_column(table, name) do
    Enum.find(table.columns, &(&1.name == name))
  end

  describe "schema discovery" do
    test "discovers public schema", %{db: db} do
      assert find_schema(db, "public") != nil
    end

    test "discovers custom schema", %{db: db} do
      assert find_schema(db, "custom_schema") != nil
    end

    test "excludes system schemas", %{db: db} do
      schema_names = Enum.map(db.schemas, & &1.name)
      refute "information_schema" in schema_names
      refute "pg_catalog" in schema_names
      refute "pg_toast" in schema_names
    end
  end

  describe "table discovery" do
    test "discovers all public tables", %{db: db} do
      public = find_schema(db, "public")
      table_names = Enum.map(public.tables, & &1.name)

      for expected <-
            ~w(users posts comments products events network_info with_arrays with_pg_enum binary_data) do
        assert expected in table_names, "expected table #{expected} in public schema"
      end
    end

    test "discovers tables in custom schema", %{db: db} do
      custom = find_schema(db, "custom_schema")
      table_names = Enum.map(custom.tables, & &1.name)
      assert "items" in table_names
    end
  end

  describe "table types" do
    test "base tables have type :table", %{db: db} do
      public = find_schema(db, "public")
      users = find_table(public, "users")
      assert users.type == :table
    end

    test "views have type :view", %{db: db} do
      public = find_schema(db, "public")
      active_users = find_table(public, "active_users")
      assert active_users != nil
      assert active_users.type == :view
    end

    test "materialized views have type :materialized_view", %{db: db} do
      public = find_schema(db, "public")
      upc = find_table(public, "user_post_counts")
      assert upc != nil
      assert upc.type == :materialized_view
    end

    test "views expose their columns", %{db: db} do
      public = find_schema(db, "public")
      active_users = find_table(public, "active_users")
      column_names = Enum.map(active_users.columns, & &1.name)

      assert "id" in column_names
      assert "name" in column_names
      assert "email" in column_names
      assert "inserted_at" in column_names
    end

    test "materialized views expose their columns", %{db: db} do
      public = find_schema(db, "public")
      upc = find_table(public, "user_post_counts")
      column_names = Enum.map(upc.columns, & &1.name)

      assert "user_id" in column_names
      assert "name" in column_names
      assert "post_count" in column_names
    end
  end

  describe "column discovery" do
    test "discovers columns for users table", %{db: db} do
      public = find_schema(db, "public")
      users = find_table(public, "users")
      column_names = Enum.map(users.columns, & &1.name)

      for expected <- ~w(id name email status inserted_at updated_at) do
        assert expected in column_names, "expected column #{expected} in users"
      end
    end
  end

  describe "primary keys" do
    test "detects serial primary key", %{db: db} do
      public = find_schema(db, "public")
      users = find_table(public, "users")
      id_col = find_column(users, "id")

      assert id_col.primary_key == true
    end

    test "detects uuid primary key", %{db: db} do
      public = find_schema(db, "public")
      products = find_table(public, "products")
      id_col = find_column(products, "id")

      assert id_col.primary_key == true
    end

    test "non-pk columns are not marked as primary key", %{db: db} do
      public = find_schema(db, "public")
      users = find_table(public, "users")
      name_col = find_column(users, "name")

      assert name_col.primary_key == false
    end

    test "detects primary key in custom schema", %{db: db} do
      custom = find_schema(db, "custom_schema")
      items = find_table(custom, "items")
      id_col = find_column(items, "id")

      assert id_col.primary_key == true
    end
  end

  describe "foreign keys" do
    test "detects FK from posts.user_id to users.id", %{db: db} do
      public = find_schema(db, "public")
      posts = find_table(public, "posts")
      user_id_col = find_column(posts, "user_id")

      assert user_id_col.foreign_key != nil
      assert user_id_col.foreign_key.schema == "public"
      assert user_id_col.foreign_key.table == "users"
      assert user_id_col.foreign_key.column == "id"
    end

    test "detects FK from comments.post_id to posts.id", %{db: db} do
      public = find_schema(db, "public")
      comments = find_table(public, "comments")
      post_id_col = find_column(comments, "post_id")

      assert post_id_col.foreign_key != nil
      assert post_id_col.foreign_key.table == "posts"
      assert post_id_col.foreign_key.column == "id"
    end

    test "detects FK from comments.user_id to users.id", %{db: db} do
      public = find_schema(db, "public")
      comments = find_table(public, "comments")
      user_id_col = find_column(comments, "user_id")

      assert user_id_col.foreign_key != nil
      assert user_id_col.foreign_key.table == "users"
      assert user_id_col.foreign_key.column == "id"
    end

    test "detects cross-schema FK from custom_schema.items to public.users", %{db: db} do
      custom = find_schema(db, "custom_schema")
      items = find_table(custom, "items")
      created_by_col = find_column(items, "created_by_id")

      assert created_by_col != nil
      assert created_by_col.foreign_key != nil
      assert created_by_col.foreign_key.schema == "public"
      assert created_by_col.foreign_key.table == "users"
      assert created_by_col.foreign_key.column == "id"
    end

    test "non-FK columns have nil foreign_key", %{db: db} do
      public = find_schema(db, "public")
      users = find_table(public, "users")
      name_col = find_column(users, "name")

      assert name_col.foreign_key == nil
    end
  end

  describe "column defaults" do
    test "exposes serial default (nextval)", %{db: db} do
      public = find_schema(db, "public")
      users = find_table(public, "users")
      id_col = find_column(users, "id")

      assert id_col.default != nil
      assert id_col.default =~ "nextval"
    end

    test "exposes now() default for timestamps", %{db: db} do
      public = find_schema(db, "public")
      users = find_table(public, "users")
      inserted_at = find_column(users, "inserted_at")

      assert inserted_at.default != nil
      assert inserted_at.default =~ "now()"
    end

    test "exposes uuid generation default", %{db: db} do
      public = find_schema(db, "public")
      products = find_table(public, "products")
      id_col = find_column(products, "id")

      assert id_col.default != nil
      assert id_col.default =~ "gen_random_uuid()"
    end

    test "exposes literal boolean default", %{db: db} do
      public = find_schema(db, "public")
      products = find_table(public, "products")
      active_col = find_column(products, "active")

      assert active_col.default == "true"
    end

    test "exposes literal integer default", %{db: db} do
      public = find_schema(db, "public")
      products = find_table(public, "products")
      quantity_col = find_column(products, "quantity")

      assert quantity_col.default == "0"
    end

    test "columns without defaults have nil", %{db: db} do
      public = find_schema(db, "public")
      users = find_table(public, "users")
      name_col = find_column(users, "name")

      assert name_col.default == nil
    end
  end

  describe "type mapping" do
    setup %{db: db} do
      public = find_schema(db, "public")
      %{public: public}
    end

    test "maps integer types", %{public: public} do
      users = find_table(public, "users")
      id_col = find_column(users, "id")
      assert id_col.type == :integer
    end

    test "maps text/varchar to string", %{public: public} do
      users = find_table(public, "users")
      assert find_column(users, "name").type == :string
      assert find_column(users, "email").type == :string
    end

    test "maps timestamptz to datetime", %{public: public} do
      users = find_table(public, "users")
      assert find_column(users, "inserted_at").type == :datetime
    end

    test "maps boolean", %{public: public} do
      posts = find_table(public, "posts")
      assert find_column(posts, "published").type == :boolean
    end

    test "maps jsonb to map", %{public: public} do
      posts = find_table(public, "posts")
      assert find_column(posts, "metadata").type == :map
    end

    test "maps numeric to float", %{public: public} do
      products = find_table(public, "products")
      assert find_column(products, "price").type == :float
    end

    test "maps uuid", %{public: public} do
      products = find_table(public, "products")
      assert find_column(products, "id").type == :uuid
    end

    test "maps date", %{public: public} do
      events = find_table(public, "events")
      assert find_column(events, "event_date").type == :date
    end

    test "maps time", %{public: public} do
      events = find_table(public, "events")
      assert find_column(events, "start_time").type == :time
    end

    test "maps naive_datetime", %{public: public} do
      events = find_table(public, "events")
      assert find_column(events, "naive_ts").type == :naive_datetime
    end

    test "maps network types to string", %{public: public} do
      net = find_table(public, "network_info")
      assert find_column(net, "ip_address").type == :string
      assert find_column(net, "network").type == :string
      assert find_column(net, "mac").type == :string
    end

    test "maps array types", %{public: public} do
      arrays = find_table(public, "with_arrays")
      assert find_column(arrays, "tags").type == {:array, :string}
      assert find_column(arrays, "scores").type == {:array, :integer}
    end

    test "maps bytea to binary", %{public: public} do
      binary = find_table(public, "binary_data")
      assert find_column(binary, "payload").type == :binary
    end
  end

  describe "nullable" do
    test "detects non-nullable columns", %{db: db} do
      public = find_schema(db, "public")
      users = find_table(public, "users")
      assert find_column(users, "name").nullable == false
    end

    test "detects nullable columns", %{db: db} do
      public = find_schema(db, "public")
      posts = find_table(public, "posts")
      assert find_column(posts, "body").nullable == true
    end
  end

  describe "PostgreSQL ENUM detection" do
    test "detects pg enum type with values", %{db: db} do
      public = find_schema(db, "public")
      pg_enum = find_table(public, "with_pg_enum")
      mood_col = find_column(pg_enum, "current_mood")

      assert mood_col.type == :string
      assert mood_col.enum_values == ["happy", "sad", "neutral", "excited"]
    end
  end

  describe "heuristic enum detection" do
    test "detects low-cardinality string column as enum-like", %{db: db} do
      public = find_schema(db, "public")
      users = find_table(public, "users")
      status_col = find_column(users, "status")

      assert status_col.enum_values != nil
      assert Enum.sort(status_col.enum_values) == ["active", "inactive", "pending"]
    end

    test "detects enum-like column in custom schema", %{db: db} do
      custom = find_schema(db, "custom_schema")
      items = find_table(custom, "items")
      category_col = find_column(items, "category")

      assert category_col.enum_values != nil
      assert Enum.sort(category_col.enum_values) == ["books", "clothing", "electronics"]
    end

    test "does NOT flag high-cardinality string columns as enum", %{db: db} do
      public = find_schema(db, "public")
      users = find_table(public, "users")
      email_col = find_column(users, "email")

      assert email_col.enum_values == nil
    end

    test "does NOT flag text body columns as enum", %{db: db} do
      public = find_schema(db, "public")
      posts = find_table(public, "posts")
      body_col = find_column(posts, "body")

      assert body_col.enum_values == nil
    end
  end

  describe "result struct types" do
    test "returns correct struct types", %{db: db} do
      assert %Result.Database{} = db
      assert [%Result.Schema{} | _] = db.schemas

      schema = hd(db.schemas)
      assert [%Result.Table{} | _] = schema.tables

      table = hd(schema.tables)
      assert [%Result.Column{} | _] = table.columns
    end
  end
end
