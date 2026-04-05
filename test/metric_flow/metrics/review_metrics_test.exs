defmodule MetricFlow.Metrics.ReviewMetricsTest do
  use MetricFlowTest.DataCase, async: true

  import MetricFlowTest.UsersFixtures

  alias MetricFlow.Metrics.Metric
  alias MetricFlow.Metrics.ReviewMetrics
  alias MetricFlow.Repo
  alias MetricFlow.Users.Scope

  # ---------------------------------------------------------------------------
  # Fixtures
  # ---------------------------------------------------------------------------

  defp user_with_scope do
    user = user_fixture()
    scope = Scope.for_user(user)
    {user, scope}
  end

  defp recorded_at_for_date(%Date{} = date) do
    DateTime.new!(date, ~T[12:00:00.000000], "Etc/UTC")
  end

  defp insert_review_count!(user, date, count) do
    %Metric{}
    |> Metric.changeset(%{
      user_id: user.id,
      metric_type: "reviews",
      metric_name: "review_count",
      value: count * 1.0,
      recorded_at: recorded_at_for_date(date),
      provider: :google_business_reviews
    })
    |> Repo.insert!()
  end

  defp insert_review_rating!(user, date, rating) do
    %Metric{}
    |> Metric.changeset(%{
      user_id: user.id,
      metric_type: "reviews",
      metric_name: "review_rating",
      value: rating,
      recorded_at: recorded_at_for_date(date),
      provider: :google_business_reviews
    })
    |> Repo.insert!()
  end

  defp today, do: Date.utc_today()
  defp days_ago(n), do: Date.add(Date.utc_today(), -n)

  # ---------------------------------------------------------------------------
  # query_rolling_review_metrics/2
  # ---------------------------------------------------------------------------

  describe "query_rolling_review_metrics/2" do
    test "returns a map with keys :review_count, :review_total_count, and :review_average_rating" do
      {_user, scope} = user_with_scope()

      result = ReviewMetrics.query_rolling_review_metrics(scope)

      assert Map.has_key?(result, :review_count)
      assert Map.has_key?(result, :review_total_count)
      assert Map.has_key?(result, :review_average_rating)
    end

    test "returns empty lists for all three keys when no review metrics exist for the user" do
      {_user, scope} = user_with_scope()

      result = ReviewMetrics.query_rolling_review_metrics(scope)

      assert result.review_count == []
      assert result.review_total_count == []
      assert result.review_average_rating == []
    end

    test ":review_count contains one entry per day with the count of reviews for that day" do
      {user, scope} = user_with_scope()

      day1 = days_ago(2)
      day2 = days_ago(1)

      insert_review_count!(user, day1, 3)
      insert_review_count!(user, day1, 2)
      insert_review_count!(user, day2, 5)

      result = ReviewMetrics.query_rolling_review_metrics(scope)

      assert length(result.review_count) == 2

      [entry1, entry2] = result.review_count
      assert entry1.date == day1
      assert entry1.value == 2.0

      assert entry2.date == day2
      assert entry2.value == 1.0
    end

    test ":review_total_count contains a running cumulative count across all days" do
      {user, scope} = user_with_scope()

      day1 = days_ago(3)
      day2 = days_ago(2)
      day3 = days_ago(1)

      insert_review_count!(user, day1, 4)
      insert_review_count!(user, day2, 6)
      insert_review_count!(user, day3, 2)

      result = ReviewMetrics.query_rolling_review_metrics(scope)

      [total1, total2, total3] = result.review_total_count
      assert total1.date == day1
      assert total1.value == 1.0

      assert total2.date == day2
      assert total2.value == 2.0

      assert total3.date == day3
      assert total3.value == 3.0
    end

    test ":review_average_rating contains the rolling average star rating up to each day" do
      {user, scope} = user_with_scope()

      day1 = days_ago(2)
      day2 = days_ago(1)

      insert_review_rating!(user, day1, 4.0)
      insert_review_rating!(user, day2, 2.0)

      result = ReviewMetrics.query_rolling_review_metrics(scope)

      [avg1, avg2] = result.review_average_rating
      assert avg1.date == day1
      assert avg1.value == 4.0

      assert avg2.date == day2
      assert_in_delta avg2.value, 3.0, 0.001
    end

    test "accepts a date_range: {start_date, end_date} option and filters results to that range" do
      {user, scope} = user_with_scope()

      in_range_date = days_ago(5)
      out_of_range_date = days_ago(20)

      insert_review_count!(user, in_range_date, 3)
      insert_review_count!(user, out_of_range_date, 10)

      start_date = days_ago(10)
      end_date = today()

      result = ReviewMetrics.query_rolling_review_metrics(scope, date_range: {start_date, end_date})

      assert length(result.review_count) == 1
      assert hd(result.review_count).date == in_range_date
    end

    test "returns results sorted by date ascending" do
      {user, scope} = user_with_scope()

      insert_review_count!(user, days_ago(3), 2)
      insert_review_count!(user, days_ago(1), 5)
      insert_review_count!(user, days_ago(2), 3)

      result = ReviewMetrics.query_rolling_review_metrics(scope)

      dates = Enum.map(result.review_count, & &1.date)
      assert dates == Enum.sort(dates, Date)
    end

    test "does not include results from other users" do
      {user, scope} = user_with_scope()
      {other_user, _other_scope} = user_with_scope()

      day = days_ago(1)
      insert_review_count!(user, day, 2)
      insert_review_count!(other_user, day, 99)

      result = ReviewMetrics.query_rolling_review_metrics(scope)

      assert length(result.review_count) == 1
      assert hd(result.review_count).value == 1.0
    end

    test "handles days with review_count rows but no review_rating rows (rating defaults to 0.0)" do
      {user, scope} = user_with_scope()

      day = days_ago(1)
      insert_review_count!(user, day, 3)

      result = ReviewMetrics.query_rolling_review_metrics(scope)

      assert length(result.review_average_rating) == 1
      assert hd(result.review_average_rating).value == 0.0
    end

    test "rolling average correctly weights ratings across multiple days" do
      {user, scope} = user_with_scope()

      day1 = days_ago(2)
      day2 = days_ago(1)

      insert_review_rating!(user, day1, 5.0)
      insert_review_rating!(user, day1, 5.0)
      insert_review_rating!(user, day1, 5.0)
      insert_review_rating!(user, day2, 2.0)

      result = ReviewMetrics.query_rolling_review_metrics(scope)

      [avg1, avg2] = result.review_average_rating

      assert avg1.date == day1
      assert_in_delta avg1.value, 5.0, 0.001

      assert avg2.date == day2
      assert_in_delta avg2.value, 4.25, 0.001
    end
  end
end
