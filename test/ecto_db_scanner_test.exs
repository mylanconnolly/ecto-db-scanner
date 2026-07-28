defmodule EctoDBScannerTest do
  use ExUnit.Case

  alias EctoDBScanner.Result

  @conn_opts [
    hostname: "localhost",
    username: "postgres",
    password: "postgres",
    database: "ecto_db_scanner_test",
    port: 5432
  ]

  setup_all do
    {:ok, db} = EctoDBScanner.scan(@conn_opts)

    %{db: db}
  end

  describe "scan/1" do
    test "returns database structure", %{db: db} do
      assert %Result.Database{schemas: schemas} = db

      schema_names = Enum.map(schemas, & &1.name)
      assert "public" in schema_names
      assert "custom_schema" in schema_names
    end

    test "discovers tables, views, and materialized views", %{db: db} do
      public = Enum.find(db.schemas, &(&1.name == "public"))
      table_map = Map.new(public.tables, &{&1.name, &1.type})

      assert table_map["users"] == :table
      assert table_map["active_users"] == :view
      assert table_map["user_post_counts"] == :materialized_view
    end

    test "includes primary key info", %{db: db} do
      public = Enum.find(db.schemas, &(&1.name == "public"))
      users = Enum.find(public.tables, &(&1.name == "users"))
      id_col = Enum.find(users.columns, &(&1.name == "id"))

      assert id_col.primary_key == true
    end

    test "includes foreign key info", %{db: db} do
      public = Enum.find(db.schemas, &(&1.name == "public"))
      posts = Enum.find(public.tables, &(&1.name == "posts"))
      user_id_col = Enum.find(posts.columns, &(&1.name == "user_id"))

      assert user_id_col.foreign_key == %{schema: "public", table: "users", column: "id"}
    end

    test "includes column defaults", %{db: db} do
      public = Enum.find(db.schemas, &(&1.name == "public"))
      users = Enum.find(public.tables, &(&1.name == "users"))
      inserted_at = Enum.find(users.columns, &(&1.name == "inserted_at"))

      assert inserted_at.default =~ "now()"
    end

    test "includes database size", %{db: db} do
      assert is_integer(db.size_bytes)
      assert db.size_bytes > 0
    end

    test "includes table sizes and row counts", %{db: db} do
      public = Enum.find(db.schemas, &(&1.name == "public"))
      users = Enum.find(public.tables, &(&1.name == "users"))

      assert users.row_count > 0
      assert users.size_bytes > 0
      assert users.total_size_bytes >= users.size_bytes
    end

    test "includes indexes", %{db: db} do
      public = Enum.find(db.schemas, &(&1.name == "public"))
      users = Enum.find(public.tables, &(&1.name == "users"))

      assert length(users.indexes) > 0
      assert %Result.Index{} = hd(users.indexes)
    end

    test "includes check constraints", %{db: db} do
      public = Enum.find(db.schemas, &(&1.name == "public"))
      products = Enum.find(public.tables, &(&1.name == "products"))

      assert length(products.check_constraints) > 0
      assert %Result.CheckConstraint{} = hd(products.check_constraints)
    end

    test "includes unique constraints", %{db: db} do
      public = Enum.find(db.schemas, &(&1.name == "public"))
      events = Enum.find(public.tables, &(&1.name == "events"))

      assert length(events.unique_constraints) > 0
      assert %Result.UniqueConstraint{} = hd(events.unique_constraints)
    end

    test "includes sequences", %{db: db} do
      public = Enum.find(db.schemas, &(&1.name == "public"))

      assert length(public.sequences) > 0
      assert %Result.Sequence{} = hd(public.sequences)
    end

    test "includes table and column comments", %{db: db} do
      public = Enum.find(db.schemas, &(&1.name == "public"))
      users = Enum.find(public.tables, &(&1.name == "users"))
      email_col = Enum.find(users.columns, &(&1.name == "email"))

      assert users.comment == "Application user accounts"
      assert email_col.comment == "Unique login email address"
    end
  end

  describe "concurrent scans" do
    test "two scans can run at the same time without colliding" do
      # Regression: scans used to start a repo registered under the
      # EctoDBScanner.Repo name, so a second concurrent scan crashed with
      # :already_started. Each scan now runs an anonymous repo instance.
      [result_a, result_b] =
        1..2
        |> Enum.map(fn _ -> Task.async(fn -> EctoDBScanner.scan(@conn_opts) end) end)
        |> Task.await_many(120_000)

      assert {:ok, %Result.Database{}} = result_a
      assert {:ok, %Result.Database{}} = result_b
    end
  end

  describe "schema scoping" do
    test ":schemas restricts the scan to only the given schemas" do
      {:ok, db} = EctoDBScanner.scan(@conn_opts ++ [schemas: ["custom_schema"]])

      assert Enum.map(db.schemas, & &1.name) == ["custom_schema"]

      [custom] = db.schemas
      assert Enum.map(custom.tables, & &1.name) == ["items"]

      # Sequences are scoped too
      assert Enum.map(custom.sequences, & &1.name) == ["items_id_seq"]

      # The scoped scan still resolves details inside the schema
      [items] = custom.tables
      id_col = Enum.find(items.columns, &(&1.name == "id"))
      category_col = Enum.find(items.columns, &(&1.name == "category"))

      assert id_col.primary_key == true
      assert Enum.sort(category_col.enum_values) == ["books", "clothing", "electronics"]
      assert items.row_count > 0
    end

    test ":exclude_schemas skips the given schemas" do
      {:ok, db} = EctoDBScanner.scan(@conn_opts ++ [exclude_schemas: ["custom_schema"]])

      schema_names = Enum.map(db.schemas, & &1.name)
      assert "public" in schema_names
      refute "custom_schema" in schema_names
    end
  end
end
