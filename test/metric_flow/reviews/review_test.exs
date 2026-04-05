defmodule MetricFlow.Reviews.ReviewTest do
  use MetricFlowTest.DataCase, async: true

  import MetricFlowTest.UsersFixtures
  import MetricFlowTest.IntegrationsFixtures

  alias MetricFlow.Reviews.Review
  alias MetricFlow.Repo

  # ---------------------------------------------------------------------------
  # Fixtures
  # ---------------------------------------------------------------------------

  defp valid_attrs(user_id, integration_id) do
    %{
      user_id: user_id,
      integration_id: integration_id,
      provider: :google_business,
      external_review_id: "review-#{System.unique_integer([:positive])}",
      reviewer_name: "Jane Doe",
      star_rating: 5,
      comment: "Excellent service!",
      review_date: ~D[2024-01-15],
      location_id: "locations/12345",
      metadata: %{"language" => "en", "reply" => "Thank you!"}
    }
  end

  defp new_review do
    struct!(Review, [])
  end

  defp insert_review!(attrs) do
    new_review()
    |> Review.changeset(attrs)
    |> Repo.insert!()
  end

  # ---------------------------------------------------------------------------
  # changeset/2
  # ---------------------------------------------------------------------------

  describe "changeset/2" do
    test "creates valid changeset with all required fields" do
      user = user_fixture()
      integration = integration_fixture(user, provider: :google_business)
      attrs = valid_attrs(user.id, integration.id)

      changeset = Review.changeset(new_review(), attrs)

      assert changeset.valid?
    end

    test "casts each field attribute correctly (integration_id, user_id, provider, external_review_id, reviewer_name, star_rating, comment, review_date, location_id, metadata)" do
      user = user_fixture()
      integration = integration_fixture(user, provider: :google_business)
      attrs = valid_attrs(user.id, integration.id)

      changeset = Review.changeset(new_review(), attrs)

      assert get_change(changeset, :integration_id) == integration.id
      assert get_change(changeset, :user_id) == user.id
      assert get_change(changeset, :provider) == :google_business
      assert get_change(changeset, :external_review_id) == attrs.external_review_id
      assert get_change(changeset, :reviewer_name) == "Jane Doe"
      assert get_change(changeset, :star_rating) == 5
      assert get_change(changeset, :comment) == "Excellent service!"
      assert get_change(changeset, :review_date) == ~D[2024-01-15]
      assert get_change(changeset, :location_id) == "locations/12345"
      assert get_change(changeset, :metadata) == %{"language" => "en", "reply" => "Thank you!"}
    end

    test "validates integration_id is required" do
      user = user_fixture()
      integration = integration_fixture(user, provider: :google_business)
      attrs = Map.delete(valid_attrs(user.id, integration.id), :integration_id)

      changeset = Review.changeset(new_review(), attrs)

      refute changeset.valid?
      assert %{integration_id: ["can't be blank"]} = errors_on(changeset)
    end

    test "validates user_id is required" do
      user = user_fixture()
      integration = integration_fixture(user, provider: :google_business)
      attrs = Map.delete(valid_attrs(user.id, integration.id), :user_id)

      changeset = Review.changeset(new_review(), attrs)

      refute changeset.valid?
      assert %{user_id: ["can't be blank"]} = errors_on(changeset)
    end

    test "validates provider is required" do
      user = user_fixture()
      integration = integration_fixture(user, provider: :google_business)
      attrs = Map.delete(valid_attrs(user.id, integration.id), :provider)

      changeset = Review.changeset(new_review(), attrs)

      refute changeset.valid?
      assert %{provider: ["can't be blank"]} = errors_on(changeset)
    end

    test "validates external_review_id is required" do
      user = user_fixture()
      integration = integration_fixture(user, provider: :google_business)
      attrs = Map.delete(valid_attrs(user.id, integration.id), :external_review_id)

      changeset = Review.changeset(new_review(), attrs)

      refute changeset.valid?
      assert %{external_review_id: ["can't be blank"]} = errors_on(changeset)
    end

    test "validates star_rating is required" do
      user = user_fixture()
      integration = integration_fixture(user, provider: :google_business)
      attrs = Map.delete(valid_attrs(user.id, integration.id), :star_rating)

      changeset = Review.changeset(new_review(), attrs)

      refute changeset.valid?
      assert %{star_rating: ["can't be blank"]} = errors_on(changeset)
    end

    test "validates review_date is required" do
      user = user_fixture()
      integration = integration_fixture(user, provider: :google_business)
      attrs = Map.delete(valid_attrs(user.id, integration.id), :review_date)

      changeset = Review.changeset(new_review(), attrs)

      refute changeset.valid?
      assert %{review_date: ["can't be blank"]} = errors_on(changeset)
    end

    test "rejects star_rating below 1" do
      user = user_fixture()
      integration = integration_fixture(user, provider: :google_business)
      attrs = %{valid_attrs(user.id, integration.id) | star_rating: 0}

      changeset = Review.changeset(new_review(), attrs)

      refute changeset.valid?
      assert %{star_rating: [_]} = errors_on(changeset)
    end

    test "rejects star_rating above 5" do
      user = user_fixture()
      integration = integration_fixture(user, provider: :google_business)
      attrs = %{valid_attrs(user.id, integration.id) | star_rating: 6}

      changeset = Review.changeset(new_review(), attrs)

      refute changeset.valid?
      assert %{star_rating: [_]} = errors_on(changeset)
    end

    test "accepts star_rating of exactly 1 (lower boundary)" do
      user = user_fixture()
      integration = integration_fixture(user, provider: :google_business)
      attrs = %{valid_attrs(user.id, integration.id) | star_rating: 1}

      changeset = Review.changeset(new_review(), attrs)

      assert changeset.valid?
    end

    test "accepts star_rating of exactly 5 (upper boundary)" do
      user = user_fixture()
      integration = integration_fixture(user, provider: :google_business)
      attrs = %{valid_attrs(user.id, integration.id) | star_rating: 5}

      changeset = Review.changeset(new_review(), attrs)

      assert changeset.valid?
    end

    test "allows nil reviewer_name (optional field)" do
      user = user_fixture()
      integration = integration_fixture(user, provider: :google_business)
      attrs = Map.put(valid_attrs(user.id, integration.id), :reviewer_name, nil)

      changeset = Review.changeset(new_review(), attrs)

      assert changeset.valid?
    end

    test "allows nil comment (optional field)" do
      user = user_fixture()
      integration = integration_fixture(user, provider: :google_business)
      attrs = Map.put(valid_attrs(user.id, integration.id), :comment, nil)

      changeset = Review.changeset(new_review(), attrs)

      assert changeset.valid?
    end

    test "allows nil location_id (optional field)" do
      user = user_fixture()
      integration = integration_fixture(user, provider: :google_business)
      attrs = Map.put(valid_attrs(user.id, integration.id), :location_id, nil)

      changeset = Review.changeset(new_review(), attrs)

      assert changeset.valid?
    end

    test "allows nil metadata (defaults to empty map)" do
      user = user_fixture()
      integration = integration_fixture(user, provider: :google_business)
      attrs = Map.delete(valid_attrs(user.id, integration.id), :metadata)

      changeset = Review.changeset(new_review(), attrs)

      assert changeset.valid?
    end

    test "validates metadata is a map when provided" do
      user = user_fixture()
      integration = integration_fixture(user, provider: :google_business)
      attrs = %{valid_attrs(user.id, integration.id) | metadata: %{"key" => "value"}}

      changeset = Review.changeset(new_review(), attrs)

      assert changeset.valid?
    end

    test "rejects metadata when not a map" do
      user = user_fixture()
      integration = integration_fixture(user, provider: :google_business)
      attrs = %{valid_attrs(user.id, integration.id) | metadata: "not-a-map"}

      changeset = Review.changeset(new_review(), attrs)

      refute changeset.valid?
      assert %{metadata: [_]} = errors_on(changeset)
    end

    test "rejects metadata when it is a list" do
      user = user_fixture()
      integration = integration_fixture(user, provider: :google_business)
      attrs = %{valid_attrs(user.id, integration.id) | metadata: ["item1", "item2"]}

      changeset = Review.changeset(new_review(), attrs)

      refute changeset.valid?
      assert %{metadata: [_]} = errors_on(changeset)
    end

    test "accepts all valid provider enum values (:google_business)" do
      user = user_fixture()
      integration = integration_fixture(user, provider: :google_business)

      for provider <- [:google_business] do
        attrs = %{valid_attrs(user.id, integration.id) | provider: provider}
        changeset = Review.changeset(new_review(), attrs)

        assert changeset.valid?, "expected #{provider} to be valid"
        assert get_change(changeset, :provider) == provider
      end
    end

    test "rejects unknown provider values" do
      user = user_fixture()
      integration = integration_fixture(user, provider: :google_business)
      attrs = %{valid_attrs(user.id, integration.id) | provider: :unknown_provider}

      changeset = Review.changeset(new_review(), attrs)

      refute changeset.valid?
      assert %{provider: [_]} = errors_on(changeset)
    end

    test "validates user association exists (assoc_constraint triggers on insert)" do
      user = user_fixture()
      integration = integration_fixture(user, provider: :google_business)
      attrs = %{valid_attrs(user.id, integration.id) | user_id: -1}

      {:error, changeset} =
        new_review()
        |> Review.changeset(attrs)
        |> Repo.insert()

      assert %{user: ["does not exist"]} = errors_on(changeset)
    end

    test "validates integration association exists (assoc_constraint triggers on insert)" do
      user = user_fixture()
      integration = integration_fixture(user, provider: :google_business)
      attrs = %{valid_attrs(user.id, integration.id) | integration_id: -1}

      {:error, changeset} =
        new_review()
        |> Review.changeset(attrs)
        |> Repo.insert()

      assert %{integration: ["does not exist"]} = errors_on(changeset)
    end

    test "creates valid changeset for updating existing review" do
      user = user_fixture()
      integration = integration_fixture(user, provider: :google_business)
      review = insert_review!(valid_attrs(user.id, integration.id))

      update_attrs = %{comment: "Updated comment"}
      changeset = Review.changeset(review, update_attrs)

      assert changeset.valid?
      assert get_change(changeset, :comment) == "Updated comment"
    end

    test "preserves existing fields when updating subset of attributes" do
      user = user_fixture()
      integration = integration_fixture(user, provider: :google_business)
      attrs = valid_attrs(user.id, integration.id)
      review = insert_review!(attrs)

      update_attrs = %{comment: "New comment"}
      changeset = Review.changeset(review, update_attrs)

      assert changeset.data.provider == :google_business
      assert changeset.data.star_rating == 5
      assert changeset.data.user_id == user.id
      assert changeset.data.integration_id == integration.id
    end

    test "handles empty attributes map gracefully" do
      user = user_fixture()
      integration = integration_fixture(user, provider: :google_business)
      review = insert_review!(valid_attrs(user.id, integration.id))

      changeset = Review.changeset(review, %{})

      assert changeset.valid?
    end
  end
end
