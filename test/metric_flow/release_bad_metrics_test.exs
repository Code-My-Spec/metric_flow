defmodule MetricFlow.ReleaseBadMetricsTest do
  use MetricFlowTest.DataCase, async: false

  import ExUnit.CaptureIO
  import MetricFlowTest.UsersFixtures

  alias MetricFlow.Metrics
  alias MetricFlow.Release

  defp metric(scope, provider, date, name, dims) do
    {:ok, _} =
      Metrics.create_metric(scope, %{
        provider: provider,
        metric_type: "x",
        metric_name: name,
        value: 1.0,
        recorded_at: DateTime.new!(date, ~T[00:00:00], "Etc/UTC"),
        dimensions: dims
      })
  end

  test "reports collapsed Meta backfills and duplicate reviews, then purges only approved accounts" do
    bad = account_scope_fixture(user_fixture())
    good = account_scope_fixture(user_fixture())
    today = Date.utc_today()

    # Collapsed backfill: one row 548 days back, then three daily rows.
    metric(bad, :facebook_ads, Date.add(today, -548), "spend", %{})
    for d <- 1..3, do: metric(bad, :facebook_ads, Date.add(today, -d), "spend", %{})
    # Healthy: three consecutive days.
    for d <- 1..3, do: metric(good, :facebook_ads, Date.add(today, -d), "spend", %{})

    review = %{location_id: "locations/1", review_id: "r1"}
    for _ <- 1..3, do: metric(bad, :google_business_reviews, today, "review_rating", review)
    metric(good, :google_business_reviews, today, "review_rating", review)

    report = capture_io(fn -> send(self(), Release.bad_metrics_report()) end)
    bad_id = bad.account_id
    assert_received %{facebook_ads: [^bad_id], google_business_reviews: [^bad_id]}
    assert report =~ "duplicate_reviews=2"

    capture_io(fn -> assert Release.purge_bad_metrics(:facebook_ads, [bad_id]) == 4 end)
    assert Metrics.list_metrics(bad, provider: :facebook_ads) == []
    refute Metrics.list_metrics(good, provider: :facebook_ads) == []
  end
end
