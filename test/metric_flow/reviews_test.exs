defmodule MetricFlow.ReviewsTest do
  use MetricFlowTest.DataCase, async: true

  import MetricFlowTest.UsersFixtures
  import MetricFlowTest.IntegrationsFixtures

  alias MetricFlow.Repo
  alias MetricFlow.Reviews
  alias MetricFlow.Reviews.Review
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
