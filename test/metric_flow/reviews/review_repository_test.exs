defmodule MetricFlow.Reviews.ReviewRepositoryTest do
  use MetricFlowTest.DataCase, async: true

  import MetricFlowTest.UsersFixtures
  import MetricFlowTest.IntegrationsFixtures

  alias MetricFlow.Reviews.Review
  alias MetricFlow.Reviews.ReviewRepository
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

  defp valid_review_attrs(user_id, integration_id, overrides \\ %{}) do
    unique = System.unique_integer([:positive])

    Map.merge(
      %{
        user_id: user_id,
        integration_id: integration_id,
        provider: :google_business,
        external_review_id: "ext-review-#{unique}",
        reviewer_name: "Reviewer #{unique}",
        star_rating: 5,
        comment: "Great service!",
        review_date: Date.utc_today(),
        location_id: "locations/12345",
        metadata: %{}
      },
      overrides
    )
  end

  defp insert_review!(user_id, integration_id, overrides \\ %{}) do
    attrs = valid_review_attrs(user_id, integration_id, overrides)

    %Review{}
    |> Review.changeset(attrs)
    |> Repo.insert!()
  end

  # ---------------------------------------------------------------------------
  # create_reviews/2
  # ---------------------------------------------------------------------------

  describe "create_reviews/2" do
    test "returns {:ok, count} with the number of inserted reviews" do
      {user, scope} = user_with_scope()
      integration = integration_fixture(user, provider: :google_business)

      attrs_list = [
        valid_review_attrs(user.id, integration.id, %{external_review_id: "ext-1"}),
        valid_review_attrs(user.id, integration.id, %{external_review_id: "ext-2"})
      ]

      assert {:ok, 2} = ReviewRepository.create_reviews(scope, attrs_list)
    end

    test "inserts all review records into the database" do
      {user, scope} = user_with_scope()
      integration = integration_fixture(user, provider: :google_business)

      attrs_list = [
        valid_review_attrs(user.id, integration.id, %{external_review_id: "ext-a"}),
        valid_review_attrs(user.id, integration.id, %{external_review_id: "ext-b"}),
        valid_review_attrs(user.id, integration.id, %{external_review_id: "ext-c"})
      ]

      {:ok, _count} = ReviewRepository.create_reviews(scope, attrs_list)

      assert Repo.aggregate(Review, :count) == 3
    end

    test "associates all inserted reviews with the user_id from scope" do
      {user, scope} = user_with_scope()
      integration = integration_fixture(user, provider: :google_business)

      attrs_list = [
        valid_review_attrs(user.id, integration.id, %{external_review_id: "ext-u1"}),
        valid_review_attrs(user.id, integration.id, %{external_review_id: "ext-u2"})
      ]

      {:ok, _count} = ReviewRepository.create_reviews(scope, attrs_list)

      inserted = Repo.all(Review)
      assert Enum.all?(inserted, &(&1.user_id == user.id))
    end

    test "deduplicates on external_review_id — updates existing review when same external_review_id is provided in a later call" do
      {user, scope} = user_with_scope()
      integration = integration_fixture(user, provider: :google_business)

      external_id = "ext-dedup-#{System.unique_integer([:positive])}"

      initial_attrs = [valid_review_attrs(user.id, integration.id, %{external_review_id: external_id, star_rating: 3})]
      {:ok, 1} = ReviewRepository.create_reviews(scope, initial_attrs)

      updated_attrs = [valid_review_attrs(user.id, integration.id, %{external_review_id: external_id, star_rating: 5})]
      {:ok, 1} = ReviewRepository.create_reviews(scope, updated_attrs)

      assert Repo.aggregate(Review, :count) == 1
      review = Repo.one(Review)
      assert review.star_rating == 5
    end

    test "does not increase the row count when reinserting reviews with existing external_review_ids" do
      {user, scope} = user_with_scope()
      integration = integration_fixture(user, provider: :google_business)

      external_id = "ext-reinsert-#{System.unique_integer([:positive])}"
      attrs = [valid_review_attrs(user.id, integration.id, %{external_review_id: external_id})]

      {:ok, 1} = ReviewRepository.create_reviews(scope, attrs)
      {:ok, 1} = ReviewRepository.create_reviews(scope, attrs)

      assert Repo.aggregate(Review, :count) == 1
    end

    test "returns {:ok, 0} for empty list input" do
      {_user, scope} = user_with_scope()

      assert {:ok, 0} = ReviewRepository.create_reviews(scope, [])
    end

    test "stores all review fields correctly" do
      {user, scope} = user_with_scope()
      integration = integration_fixture(user, provider: :google_business)

      external_id = "ext-fields-#{System.unique_integer([:positive])}"
      review_date = ~D[2024-03-15]
      metadata = %{"language" => "en"}

      attrs_list = [
        %{
          user_id: user.id,
          integration_id: integration.id,
          provider: :google_business,
          external_review_id: external_id,
          reviewer_name: "Jane Doe",
          star_rating: 4,
          comment: "Very good!",
          review_date: review_date,
          location_id: "locations/99",
          metadata: metadata
        }
      ]

      {:ok, 1} = ReviewRepository.create_reviews(scope, attrs_list)

      review = Repo.one(Review)
      assert review.external_review_id == external_id
      assert review.reviewer_name == "Jane Doe"
      assert review.star_rating == 4
      assert review.comment == "Very good!"
      assert review.review_date == review_date
      assert review.location_id == "locations/99"
      assert review.metadata == metadata
    end

    test "accepts string keys in attrs maps" do
      {user, scope} = user_with_scope()
      integration = integration_fixture(user, provider: :google_business)

      external_id = "ext-str-#{System.unique_integer([:positive])}"

      attrs_list = [
        %{
          "user_id" => user.id,
          "integration_id" => integration.id,
          "provider" => "google_business",
          "external_review_id" => external_id,
          "star_rating" => 3,
          "review_date" => Date.utc_today()
        }
      ]

      assert {:ok, 1} = ReviewRepository.create_reviews(scope, attrs_list)
    end

    test "sets inserted_at and updated_at timestamps on inserted records" do
      {user, scope} = user_with_scope()
      integration = integration_fixture(user, provider: :google_business)

      attrs_list = [valid_review_attrs(user.id, integration.id)]

      {:ok, _count} = ReviewRepository.create_reviews(scope, attrs_list)

      inserted = Repo.all(Review)
      assert Enum.all?(inserted, &(&1.inserted_at != nil))
      assert Enum.all?(inserted, &(&1.updated_at != nil))
    end
  end

  # ---------------------------------------------------------------------------
  # list_reviews/2
  # ---------------------------------------------------------------------------

  describe "list_reviews/2" do
    test "returns list of reviews for scoped user" do
      {user, scope} = user_with_scope()
      integration = integration_fixture(user, provider: :google_business)

      insert_review!(user.id, integration.id)
      insert_review!(user.id, integration.id)

      results = ReviewRepository.list_reviews(scope)

      assert length(results) == 2
    end

    test "returns empty list when user has no reviews" do
      {_user, scope} = user_with_scope()

      assert ReviewRepository.list_reviews(scope) == []
    end

    test "does not return reviews belonging to other users" do
      {user, scope} = user_with_scope()
      {other_user, _other_scope} = user_with_scope()

      other_integration = integration_fixture(other_user, provider: :google_business)
      insert_review!(other_user.id, other_integration.id)

      integration = integration_fixture(user, provider: :google_business)
      insert_review!(user.id, integration.id)

      results = ReviewRepository.list_reviews(scope)

      assert length(results) == 1
      assert hd(results).user_id == user.id
    end

    test "enforces multi-tenant isolation" do
      {user_a, scope_a} = user_with_scope()
      {user_b, _scope_b} = user_with_scope()

      integration_a = integration_fixture(user_a, provider: :google_business)
      integration_b = integration_fixture(user_b, provider: :google_business)

      insert_review!(user_a.id, integration_a.id)
      insert_review!(user_b.id, integration_b.id)
      insert_review!(user_b.id, integration_b.id)

      results = ReviewRepository.list_reviews(scope_a)

      assert length(results) == 1
      assert hd(results).user_id == user_a.id
    end

    test "filters by provider when provider option is provided" do
      {user, scope} = user_with_scope()
      integration = integration_fixture(user, provider: :google_business)

      insert_review!(user.id, integration.id, %{provider: :google_business})

      results = ReviewRepository.list_reviews(scope, provider: :google_business)

      assert length(results) == 1
      assert hd(results).provider == :google_business
    end

    test "filters by location_id when location_id option is provided" do
      {user, scope} = user_with_scope()
      integration = integration_fixture(user, provider: :google_business)

      insert_review!(user.id, integration.id, %{location_id: "locations/111"})
      insert_review!(user.id, integration.id, %{location_id: "locations/222"})

      results = ReviewRepository.list_reviews(scope, location_id: "locations/111")

      assert length(results) == 1
      assert hd(results).location_id == "locations/111"
    end

    test "filters by date_range when date_range option is provided as {start_date, end_date}" do
      {user, scope} = user_with_scope()
      integration = integration_fixture(user, provider: :google_business)

      in_range_date = Date.utc_today() |> Date.add(-5)
      out_of_range_date = Date.utc_today() |> Date.add(-20)

      insert_review!(user.id, integration.id, %{review_date: in_range_date})
      insert_review!(user.id, integration.id, %{review_date: out_of_range_date})

      start_date = Date.utc_today() |> Date.add(-10)
      end_date = Date.utc_today()

      results = ReviewRepository.list_reviews(scope, date_range: {start_date, end_date})

      assert length(results) == 1
      assert hd(results).review_date == in_range_date
    end

    test "applies limit when limit option is provided" do
      {user, scope} = user_with_scope()
      integration = integration_fixture(user, provider: :google_business)

      insert_review!(user.id, integration.id)
      insert_review!(user.id, integration.id)
      insert_review!(user.id, integration.id)

      results = ReviewRepository.list_reviews(scope, limit: 2)

      assert length(results) == 2
    end

    test "applies offset when offset option is provided" do
      {user, scope} = user_with_scope()
      integration = integration_fixture(user, provider: :google_business)

      insert_review!(user.id, integration.id, %{review_date: Date.utc_today() |> Date.add(-3)})
      insert_review!(user.id, integration.id, %{review_date: Date.utc_today() |> Date.add(-2)})
      insert_review!(user.id, integration.id, %{review_date: Date.utc_today() |> Date.add(-1)})

      results = ReviewRepository.list_reviews(scope, offset: 1)

      assert length(results) == 2
    end

    test "orders results by review_date descending" do
      {user, scope} = user_with_scope()
      integration = integration_fixture(user, provider: :google_business)

      older = insert_review!(user.id, integration.id, %{review_date: Date.utc_today() |> Date.add(-5)})
      newer = insert_review!(user.id, integration.id, %{review_date: Date.utc_today() |> Date.add(-1)})

      results = ReviewRepository.list_reviews(scope)
      result_ids = Enum.map(results, & &1.id)

      assert result_ids == [newer.id, older.id]
    end

    test "filters by a list of providers when provider option is a list" do
      {user, scope} = user_with_scope()
      integration = integration_fixture(user, provider: :google_business)

      insert_review!(user.id, integration.id, %{provider: :google_business})

      results = ReviewRepository.list_reviews(scope, provider: [:google_business])

      assert length(results) == 1
      assert hd(results).provider == :google_business
    end

    test "returns reviews matching start date boundary of date_range" do
      {user, scope} = user_with_scope()
      integration = integration_fixture(user, provider: :google_business)

      boundary_date = Date.utc_today() |> Date.add(-10)
      insert_review!(user.id, integration.id, %{review_date: boundary_date})

      results = ReviewRepository.list_reviews(scope, date_range: {boundary_date, Date.utc_today()})

      assert length(results) == 1
    end

    test "returns reviews matching end date boundary of date_range" do
      {user, scope} = user_with_scope()
      integration = integration_fixture(user, provider: :google_business)

      boundary_date = Date.utc_today()
      insert_review!(user.id, integration.id, %{review_date: boundary_date})

      results = ReviewRepository.list_reviews(scope, date_range: {Date.utc_today() |> Date.add(-10), boundary_date})

      assert length(results) == 1
    end
  end

  # ---------------------------------------------------------------------------
  # delete_reviews_by_provider/2
  # ---------------------------------------------------------------------------

  describe "delete_reviews_by_provider/2" do
    test "returns {:ok, count} with the number of deleted reviews" do
      {user, scope} = user_with_scope()
      integration = integration_fixture(user, provider: :google_business)

      insert_review!(user.id, integration.id, %{provider: :google_business})
      insert_review!(user.id, integration.id, %{provider: :google_business})

      assert {:ok, 2} = ReviewRepository.delete_reviews_by_provider(scope, :google_business)
    end

    test "deletes all reviews for the specified provider and scoped user" do
      {user, scope} = user_with_scope()
      integration = integration_fixture(user, provider: :google_business)

      insert_review!(user.id, integration.id, %{provider: :google_business})
      insert_review!(user.id, integration.id, %{provider: :google_business})

      {:ok, _count} = ReviewRepository.delete_reviews_by_provider(scope, :google_business)

      assert Repo.aggregate(Review, :count) == 0
    end

    test "removes reviews matching the specified provider leaving the database empty for that user" do
      {user, scope} = user_with_scope()
      integration = integration_fixture(user, provider: :google_business)

      review = insert_review!(user.id, integration.id, %{provider: :google_business})

      {:ok, _count} = ReviewRepository.delete_reviews_by_provider(scope, :google_business)

      assert Repo.get(Review, review.id) == nil
    end

    test "does not delete reviews belonging to other users" do
      {user, scope} = user_with_scope()
      {other_user, _other_scope} = user_with_scope()

      integration = integration_fixture(user, provider: :google_business)
      other_integration = integration_fixture(other_user, provider: :google_business)

      insert_review!(user.id, integration.id, %{provider: :google_business})
      other_review = insert_review!(other_user.id, other_integration.id, %{provider: :google_business})

      {:ok, _count} = ReviewRepository.delete_reviews_by_provider(scope, :google_business)

      assert Repo.get(Review, other_review.id) != nil
    end

    test "returns {:ok, 0} when no reviews match the provider" do
      {_user, scope} = user_with_scope()

      assert {:ok, 0} = ReviewRepository.delete_reviews_by_provider(scope, :google_business)
    end

    test "enforces multi-tenant isolation" do
      {user_a, scope_a} = user_with_scope()
      {user_b, _scope_b} = user_with_scope()

      integration_a = integration_fixture(user_a, provider: :google_business)
      integration_b = integration_fixture(user_b, provider: :google_business)

      insert_review!(user_a.id, integration_a.id, %{provider: :google_business})
      other_review = insert_review!(user_b.id, integration_b.id, %{provider: :google_business})

      {:ok, count} = ReviewRepository.delete_reviews_by_provider(scope_a, :google_business)

      assert count == 1
      assert Repo.get(Review, other_review.id) != nil
    end
  end
end
