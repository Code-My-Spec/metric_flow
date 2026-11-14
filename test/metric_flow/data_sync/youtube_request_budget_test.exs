defmodule MetricFlow.DataSync.YouTubeRequestBudgetTest do
  use MetricFlowTest.DataCase, async: true

  alias MetricFlow.DataSync.YouTubeRequestBudget, as: Budget

  @now ~U[2026-10-03 12:00:00.000000Z]

  test "exhaustion prevents reservations while APIs remain independent" do
    assert {:ok, window} = Budget.reserve("data", @now)
    Repo.query!("UPDATE youtube_request_budgets SET requests = 9000 WHERE api = $1", ["data"])
    assert {:error, :quota_exceeded} = Budget.reserve("data", @now)
    assert {:ok, ^window} = Budget.reserve("analytics", @now)
  end

  test "provider quota blocks subsequent reservations until Pacific midnight" do
    assert {:ok, window} = Budget.reserve("data", @now)
    assert :ok = Budget.block("data", window)
    assert {:error, :quota_exceeded} = Budget.reserve("data", ~U[2026-10-04 06:59:59.000000Z])
    assert {:ok, next_window} = Budget.reserve("data", ~U[2026-10-04 07:00:00.000000Z])
    refute next_window == window
    assert :ok = Budget.block("data", window)
    assert {:ok, ^next_window} = Budget.reserve("data", ~U[2026-10-04 07:00:01.000000Z])
  end

  test "winter reset follows Pacific standard time" do
    assert {:ok, window} = Budget.reserve("data", ~U[2026-12-03 12:00:00.000000Z])
    assert :ok = Budget.block("data", window)
    assert {:error, :quota_exceeded} = Budget.reserve("data", ~U[2026-12-04 07:59:59.000000Z])
    assert {:ok, _} = Budget.reserve("data", ~U[2026-12-04 08:00:00.000000Z])
  end

  test "reservations count each attempt and an older timestamp cannot reset usage" do
    assert {:ok, window} = Budget.reserve("analytics", @now)
    assert {:ok, ^window} = Budget.reserve("analytics", @now)

    assert %{rows: [[2]]} =
             Repo.query!("SELECT requests FROM youtube_request_budgets WHERE api = $1", [
               "analytics"
             ])

    assert {:error, :quota_exceeded} = Budget.reserve("analytics", DateTime.add(@now, -86_400))
  end
end
