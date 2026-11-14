defmodule MetricFlow.DataSync.YouTubeReportTest do
  use ExUnit.Case, async: true
  alias MetricFlow.DataSync.YouTubeReport

  @date ~D[2026-10-01]

  defp report(rows) do
    %{
      "columnHeaders" => [
        %{"name" => "views", "columnType" => "METRIC"},
        %{"name" => "day", "columnType" => "DIMENSION"}
      ],
      "rows" => rows
    }
  end

  test "uses header order and preserves numeric zero" do
    assert {:ok, [row]} =
             YouTubeReport.parse(report([[0, "2026-10-01"]]), ["views"], {@date, @date})

    assert row.metric_name == "views"
    assert row.report_date == @date
    assert Decimal.equal?(row.value, 0)
    assert {:ok, []} = YouTubeReport.parse(report([]), ["views"], {@date, @date})
  end

  test "rejects invalid cells, duplicate days and dates outside the fetched slice" do
    for rows <- [
          [[nil, "2026-10-01"]],
          [["NaN", "2026-10-01"]],
          [[-1, "2026-10-01"]],
          [[1, "2026-10-02"]],
          [[1, "2026-10-01"], [2, "2026-10-01"]],
          [[1]]
        ] do
      assert {:error, :malformed_report} =
               YouTubeReport.parse(report(rows), ["views"], {@date, @date})
    end
  end

  test "normalizes missing comments without inventing revenue" do
    for name <- ["comments", "estimatedRevenue"] do
      body = %{
        "columnHeaders" => [
          %{"name" => name, "columnType" => "METRIC"},
          %{"name" => "day", "columnType" => "DIMENSION"}
        ],
        "rows" => [[nil, "2026-10-01"]]
      }

      result = YouTubeReport.parse(body, [name], {@date, @date})

      if name == "comments" do
        assert {:ok, [row]} = result
        assert Decimal.equal?(row.value, 0)
      else
        assert {:error, :malformed_report} = result
      end
    end
  end

  test "rejects missing columns and incomplete pagination" do
    assert {:error, :malformed_report} =
             YouTubeReport.parse(report([]), ["views", "likes"], {@date, @date})

    body = Map.put(report([]), "nextPageToken", "next")
    assert {:error, :malformed_report} = YouTubeReport.parse(body, ["views"], {@date, @date})
  end
end
