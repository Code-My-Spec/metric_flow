defmodule MetricFlow.ReviewsTest do
  use MetricFlowTest.DataCase, async: true

  import MetricFlowTest.UsersFixtures
  import MetricFlowTest.IntegrationsFixtures

  alias MetricFlow.Reviews
  alias MetricFlow.Reviews.Review
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

  defp valid_review_attrs(user_id, integration_id, overrides) do
    Map.merge(
      %{
        user_id: user_id,
        integration_id: integration_id,
        provider: :google_business,
        external_review_id: unique_external_id(),
        reviewer_name: "Reviewer #{System.unique_integer([:positive])}",
        star_rating: 5,
        comment: "Great service!",
        review_date: Date.utc_today(),
        location_id: "locations/12345",
        metadata: %{}
      },
      overrides
    )
  end

  defp insert_review!(user, integration, overrides \\ %{}) do
    attrs = valid_review_attrs(user.id, integration.id, overrides)

    %Review{}
    |> Review.changeset(attrs)
    |> Repo.insert!()
  end

  defp days_ago(n), do: Date.add(Date.utc_today(), -n)

  # ---------------------------------------------------------------------------
  # query_rolling_review_metrics/2
  # ---------------------------------------------------------------------------

  describe "query_rolling_review_metrics/2" do
    test "returns empty lists when no reviews exist" do
      {_user, scope} = user_with_scope()

      result = Reviews.query_rolling_review_metrics(scope)

      assert result.review_count == []
      assert result.review_total_count == []
      assert result.review_average_rating == []
    end

    test "computes correct daily review count" do
      {user, scope} = user_with_scope()
      integration = integration_fixture(user, provider: :google_business)

      day = days_ago(1)
      insert_review!(user, integration, %{review_date: day, star_rating: 4})
      insert_review!(user, integration, %{review_date: day, star_rating: 5})

      result = Reviews.query_rolling_review_metrics(scope)

      assert length(result.review_count) == 1
      [entry] = result.review_count
      assert entry.date == day
      assert entry.value == 2.0
    end

    test "computes correct running total count across multiple days" do
      {user, scope} = user_with_scope()
      integration = integration_fixture(user, provider: :google_business)

      day1 = days_ago(3)
      day2 = days_ago(2)
      day3 = days_ago(1)

      insert_review!(user, integration, %{review_date: day1, star_rating: 5})
      insert_review!(user, integration, %{review_date: day2, star_rating: 4})
      insert_review!(user, integration, %{review_date: day3, star_rating: 3})

      result = Reviews.query_rolling_review_metrics(scope)

      [total1, total2, total3] = result.review_total_count
      assert total1.date == day1
      assert total1.value == 1.0

      assert total2.date == day2
      assert total2.value == 2.0

      assert total3.date == day3
      assert total3.value == 3.0
    end

    test "computes correct rolling average rating" do
      {user, scope} = user_with_scope()
      integration = integration_fixture(user, provider: :google_business)

      day1 = days_ago(2)
      day2 = days_ago(1)

      insert_review!(user, integration, %{review_date: day1, star_rating: 4})
      insert_review!(user, integration, %{review_date: day2, star_rating: 2})

      result = Reviews.query_rolling_review_metrics(scope)

      [avg1, avg2] = result.review_average_rating
      assert avg1.date == day1
      assert avg1.value == 4.0

      assert avg2.date == day2
      assert_in_delta avg2.value, 3.0, 0.001
    end

    test "filters by date range when provided" do
      {user, scope} = user_with_scope()
      integration = integration_fixture(user, provider: :google_business)

      in_range_date = days_ago(5)
      out_of_range_date = days_ago(20)

      insert_review!(user, integration, %{review_date: in_range_date, star_rating: 5})
      insert_review!(user, integration, %{review_date: out_of_range_date, star_rating: 3})

      start_date = days_ago(10)
      end_date = Date.utc_today()

      result = Reviews.query_rolling_review_metrics(scope, date_range: {start_date, end_date})

      assert length(result.review_count) == 1
      assert hd(result.review_count).date == in_range_date
    end

    test "filters by provider when provided" do
      {user, scope} = user_with_scope()
      integration = integration_fixture(user, provider: :google_business)

      day = days_ago(1)
      insert_review!(user, integration, %{review_date: day, star_rating: 5, provider: :google_business})

      result = Reviews.query_rolling_review_metrics(scope, provider: :google_business)

      assert length(result.review_count) == 1
    end

    test "aggregates across all providers when no provider filter" do
      {user, scope} = user_with_scope()
      integration = integration_fixture(user, provider: :google_business)

      day = days_ago(1)
      insert_review!(user, integration, %{review_date: day, star_rating: 4, provider: :google_business})
      insert_review!(user, integration, %{review_date: day, star_rating: 5, provider: :google_business})
      insert_review!(user, integration, %{review_date: day, star_rating: 3, provider: :google_business})

      result = Reviews.query_rolling_review_metrics(scope)

      assert length(result.review_count) == 1
      assert hd(result.review_count).value == 3.0
    end
  end

  # ---------------------------------------------------------------------------
  # review_count/1
  # ---------------------------------------------------------------------------

  describe "review_count/1" do
    test "returns 0 when no reviews exist" do
      {_user, scope} = user_with_scope()

      assert Reviews.review_count(scope) == 0
    end

    test "returns correct count across all providers" do
      {user, scope} = user_with_scope()
      integration = integration_fixture(user, provider: :google_business)

      insert_review!(user, integration)
      insert_review!(user, integration)
      insert_review!(user, integration)

      assert Reviews.review_count(scope) == 3
    end
  end

  # ---------------------------------------------------------------------------
  # recent_reviews/2
  # ---------------------------------------------------------------------------

  describe "recent_reviews/2" do
    test "returns reviews ordered by most recent first" do
      {user, scope} = user_with_scope()
      integration = integration_fixture(user, provider: :google_business)

      older = insert_review!(user, integration, %{review_date: days_ago(5)})
      newer = insert_review!(user, integration, %{review_date: days_ago(1)})

      results = Reviews.recent_reviews(scope)
      result_ids = Enum.map(results, & &1.id)

      assert result_ids == [newer.id, older.id]
    end

    test "respects limit option" do
      {user, scope} = user_with_scope()
      integration = integration_fixture(user, provider: :google_business)

      for n <- 1..5 do
        insert_review!(user, integration, %{review_date: days_ago(n)})
      end

      results = Reviews.recent_reviews(scope, limit: 3)

      assert length(results) == 3
    end

    test "filters by provider when specified" do
      {user, scope} = user_with_scope()
      integration = integration_fixture(user, provider: :google_business)

      insert_review!(user, integration, %{provider: :google_business})
      insert_review!(user, integration, %{provider: :google_business})

      results = Reviews.recent_reviews(scope, provider: :google_business)

      assert Enum.all?(results, &(&1.provider == :google_business))
    end

    test "returns empty list when no reviews exist" do
      {_user, scope} = user_with_scope()

      assert Reviews.recent_reviews(scope) == []
    end
  end
end
