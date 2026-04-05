defmodule MetricFlow.Reviews.ReviewMetricsTest do
  use MetricFlowTest.DataCase, async: true

  import MetricFlowTest.UsersFixtures
  import MetricFlowTest.IntegrationsFixtures

  alias MetricFlow.Reviews.Review
  alias MetricFlow.Reviews.ReviewMetrics
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

  defp unique_external_id do
    "review-#{System.unique_integer([:positive])}"
  end

  defp insert_review!(user, integration, attrs) do
    defaults = %{
      user_id: user.id,
      integration_id: integration.id,
      provider: :google_business,
      external_review_id: unique_external_id(),
      star_rating: 5,
      review_date: Date.utc_today()
    }

    merged = Map.merge(defaults, attrs)

    %Review{}
    |> Review.changeset(merged)
    |> Repo.insert!()
  end

  defp insert_review_without_rating!(user, integration, date) do
    Repo.insert_all("reviews", [
      %{
        user_id: user.id,
        integration_id: integration.id,
        provider: "google_business",
        external_review_id: unique_external_id(),
        star_rating: nil,
        review_date: date,
        metadata: "{}",
        inserted_at: DateTime.utc_now() |> DateTime.truncate(:microsecond),
        updated_at: DateTime.utc_now() |> DateTime.truncate(:microsecond)
      }
    ])
  end

  defp days_ago(n), do: Date.add(Date.utc_today(), -n)
  defp today, do: Date.utc_today()

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

    test "returns empty lists for all three keys when no reviews exist for the user" do
      {_user, scope} = user_with_scope()

      result = ReviewMetrics.query_rolling_review_metrics(scope)

      assert result.review_count == []
      assert result.review_total_count == []
      assert result.review_average_rating == []
    end

    test ":review_count contains one entry per day with the count of reviews received on that day as a float" do
      {user, scope} = user_with_scope()
      integration = integration_fixture(user, provider: :google_business)

      day1 = days_ago(2)
      day2 = days_ago(1)

      insert_review!(user, integration, %{review_date: day1, star_rating: 4})
      insert_review!(user, integration, %{review_date: day1, star_rating: 5})
      insert_review!(user, integration, %{review_date: day2, star_rating: 3})

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
      integration = integration_fixture(user, provider: :google_business)

      day1 = days_ago(3)
      day2 = days_ago(2)
      day3 = days_ago(1)

      insert_review!(user, integration, %{review_date: day1, star_rating: 5})
      insert_review!(user, integration, %{review_date: day2, star_rating: 4})
      insert_review!(user, integration, %{review_date: day3, star_rating: 3})

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
      integration = integration_fixture(user, provider: :google_business)

      day1 = days_ago(2)
      day2 = days_ago(1)

      insert_review!(user, integration, %{review_date: day1, star_rating: 4})
      insert_review!(user, integration, %{review_date: day2, star_rating: 2})

      result = ReviewMetrics.query_rolling_review_metrics(scope)

      [avg1, avg2] = result.review_average_rating
      assert avg1.date == day1
      assert avg1.value == 4.0

      assert avg2.date == day2
      assert_in_delta avg2.value, 3.0, 0.001
    end

    test "accepts a date_range: {start_date, end_date} option and filters results to that range" do
      {user, scope} = user_with_scope()
      integration = integration_fixture(user, provider: :google_business)

      in_range_date = days_ago(5)
      out_of_range_date = days_ago(20)

      insert_review!(user, integration, %{review_date: in_range_date, star_rating: 5})
      insert_review!(user, integration, %{review_date: out_of_range_date, star_rating: 3})

      start_date = days_ago(10)
      end_date = today()

      result = ReviewMetrics.query_rolling_review_metrics(scope, date_range: {start_date, end_date})

      assert length(result.review_count) == 1
      assert hd(result.review_count).date == in_range_date
    end

    test "returns results sorted by date ascending" do
      {user, scope} = user_with_scope()
      integration = integration_fixture(user, provider: :google_business)

      insert_review!(user, integration, %{review_date: days_ago(3), star_rating: 5})
      insert_review!(user, integration, %{review_date: days_ago(1), star_rating: 4})
      insert_review!(user, integration, %{review_date: days_ago(2), star_rating: 3})

      result = ReviewMetrics.query_rolling_review_metrics(scope)

      dates = Enum.map(result.review_count, & &1.date)
      assert dates == Enum.sort(dates, Date)
    end

    test "does not include reviews belonging to other users" do
      {user, scope} = user_with_scope()
      {other_user, _other_scope} = user_with_scope()

      integration = integration_fixture(user, provider: :google_business)
      other_integration = integration_fixture(other_user, provider: :google_business)

      day = days_ago(1)
      insert_review!(user, integration, %{review_date: day, star_rating: 4})
      insert_review!(other_user, other_integration, %{review_date: day, star_rating: 5})

      result = ReviewMetrics.query_rolling_review_metrics(scope)

      assert length(result.review_count) == 1
      assert hd(result.review_count).value == 1.0
    end

    test "handles days with reviews but no star rating (rating defaults to 0.0)" do
      {user, scope} = user_with_scope()
      integration = integration_fixture(user, provider: :google_business)

      day = days_ago(1)
      insert_review_without_rating!(user, integration, day)

      result = ReviewMetrics.query_rolling_review_metrics(scope)

      assert length(result.review_average_rating) == 1
      assert hd(result.review_average_rating).value == 0.0
    end

    test "rolling average correctly weights ratings accumulated across multiple days" do
      {user, scope} = user_with_scope()
      integration = integration_fixture(user, provider: :google_business)

      day1 = days_ago(2)
      day2 = days_ago(1)

      insert_review!(user, integration, %{review_date: day1, star_rating: 5})
      insert_review!(user, integration, %{review_date: day1, star_rating: 5})
      insert_review!(user, integration, %{review_date: day1, star_rating: 5})
      insert_review!(user, integration, %{review_date: day2, star_rating: 2})

      result = ReviewMetrics.query_rolling_review_metrics(scope)

      [avg1, avg2] = result.review_average_rating

      assert avg1.date == day1
      assert_in_delta avg1.value, 5.0, 0.001

      assert avg2.date == day2
      assert_in_delta avg2.value, 4.25, 0.001
    end

    test "aggregates reviews from all providers without filtering by provider" do
      {user, scope} = user_with_scope()
      integration = integration_fixture(user, provider: :google_business)

      day = days_ago(1)

      insert_review!(user, integration, %{review_date: day, star_rating: 4, provider: :google_business})
      insert_review!(user, integration, %{review_date: day, star_rating: 2, provider: :google_business})
      insert_review!(user, integration, %{review_date: day, star_rating: 5, provider: :google_business})

      result = ReviewMetrics.query_rolling_review_metrics(scope)

      assert length(result.review_count) == 1
      assert hd(result.review_count).value == 3.0
    end
  end
end
