defmodule EctoDBScanner.EnumDetectorTest do
  use ExUnit.Case

  import ExUnit.CaptureLog

  alias EctoDBScanner.EnumDetector
  alias EctoDBScanner.Steps.DetectEnums
  alias EctoDBScanner.TestRepo

  defp string_column(schema, table, column) do
    %{table_schema: schema, table_name: table, column_name: column, mapped_type: :string}
  end

  describe "detect_heuristic_enums/4 when a column's sampling query fails" do
    # Regression: a failed sampling query (e.g. a pool checkout dropped with
    # :queue_timeout) crashed its task, which took the whole DetectEnums step
    # and scan down with it. Failures now drop just that column.
    test "drops failing columns on the full-scan path and keeps the rest" do
      tables = [{"public", "users", 250}, {"public", "no_such_table", 250}]

      columns = [
        string_column("public", "users", "status"),
        string_column("public", "no_such_table", "status")
      ]

      log =
        capture_log(fn ->
          result = EnumDetector.detect_heuristic_enums(TestRepo, tables, columns)

          assert Enum.sort(result[{"public", "users", "status"}]) ==
                   ["active", "inactive", "pending"]

          refute Map.has_key?(result, {"public", "no_such_table", "status"})
        end)

      assert log =~ "skipping enum detection for public.no_such_table.status"
    end

    test "drops failing columns on the TABLESAMPLE path and keeps the rest" do
      # Counts above the 100k sampling threshold route through TABLESAMPLE.
      tables = [{"public", "users", 200_000}, {"public", "no_such_table", 200_000}]

      columns = [
        string_column("public", "users", "status"),
        string_column("public", "no_such_table", "status")
      ]

      log =
        capture_log(fn ->
          result = EnumDetector.detect_heuristic_enums(TestRepo, tables, columns)

          refute Map.has_key?(result, {"public", "no_such_table", "status"})
          # users.status is sampled rather than crashing; with a fake 200k count
          # the ratio check decides whether it qualifies, so only assert shape.
          assert result |> Map.keys() |> Enum.all?(&(elem(&1, 1) == "users"))
        end)

      assert log =~ "skipping enum detection for public.no_such_table.status"
    end
  end

  describe "DetectEnums.detector_opts/2" do
    test "derives concurrency from the scan's own pool size" do
      # Regression: this used repo.config()[:pool_size], i.e. app config,
      # so a scan started with pool_size: 12 still sampled 4 columns at once.
      assert DetectEnums.detector_opts(%{pool_size: 12}, TestRepo)[:pool_size] == 12
    end

    test "falls back to the repo's configured pool size" do
      assert DetectEnums.detector_opts(%{}, TestRepo)[:pool_size] == 10
    end

    test "passes explicit concurrency and timeout through" do
      opts =
        DetectEnums.detector_opts(
          %{enum_detection_max_concurrency: 2, enum_detection_timeout: 5_000},
          TestRepo
        )

      assert opts[:max_concurrency] == 2
      assert opts[:timeout] == 5_000
    end
  end
end
