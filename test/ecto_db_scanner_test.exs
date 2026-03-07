defmodule EctoDBScannerTest do
  use ExUnit.Case

  alias EctoDBScanner.Result

  setup_all do
    {:ok, db} =
      EctoDBScanner.scan(
        hostname: "localhost",
        username: "postgres",
        password: "postgres",
        database: "ecto_db_scanner_test",
        port: 5432
      )

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
  end
end
