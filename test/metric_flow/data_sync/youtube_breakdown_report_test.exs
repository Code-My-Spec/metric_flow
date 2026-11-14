defmodule MetricFlow.DataSync.YouTubeBreakdownReportTest do
  use ExUnit.Case, async: true
  alias MetricFlow.DataSync.YouTubeBreakdownReport, as: Report

  @day ~D[2026-10-01]

  defp body(type, rows) do
    headers =
      Enum.map(
        Report.dimensions(type),
        &%{"name" => &1, "columnType" => "DIMENSION"}
      ) ++
        Enum.map(Report.metrics(), &%{"name" => &1, "columnType" => "METRIC"})

    %{"columnHeaders" => headers, "rows" => rows}
  end

  test "keeps distinct categories for the same day across daily breakdown types" do
    for type <- Report.types() -- ["country"] do
      response = body(type, [["2026-10-01", "first", 10, 20], ["2026-10-01", "second", 0, 0]])
      assert {:ok, rows} = Report.parse(response, type, {@day, @day})
      assert length(rows) == 4
      assert Enum.all?(rows, &(&1.breakdown_type == type and &1.report_date == @day))
      assert MapSet.new(Enum.map(rows, & &1.breakdown_key)) == MapSet.new(["first", "second"])

      assert Enum.all?(
               Enum.filter(rows, &(&1.breakdown_key == "second")),
               &Decimal.equal?(&1.value, 0)
             )
    end
  end

  test "country rows use the requested single day and reject multi-day totals" do
    response = body("country", [["US", 10, 20], ["CA", 5, 8]])
    assert {:ok, rows} = Report.parse(response, "country", {@day, @day})
    assert Enum.all?(rows, &(&1.report_date == @day))

    assert {:error, :malformed_report} =
             Report.parse(response, "country", {@day, Date.add(@day, 1)})
  end

  test "rejects duplicate categories, invalid values, dates, and row widths" do
    for rows <- [
          [["2026-10-01", "mobile", 1, 2], ["2026-10-01", "mobile", 3, 4]],
          [["2026-10-01", "mobile", nil, 2]],
          [["2026-10-02", "mobile", 1, 2]],
          [["2026-10-01", "", 1, 2]],
          [["2026-10-01", "mobile", 1]]
        ] do
      assert {:error, :malformed_report} =
               Report.parse(body("device_type", rows), "device_type", {@day, @day})
    end
  end

  test "accepts empty tables but rejects unexpected pagination and columns" do
    response = body("country", [])
    assert {:ok, []} = Report.parse(response, "country", {@day, @day})
    assert {:ok, []} = Report.parse(Map.delete(response, "rows"), "country", {@day, @day})

    assert {:error, :malformed_report} =
             Report.parse(Map.put(response, "nextPageToken", "more"), "country", {@day, @day})

    assert {:error, :malformed_report} = Report.parse(response, "device_type", {@day, @day})
  end
end
