defmodule MetricFlow.Ai.SuggestionFeedbackTest do
  use MetricFlowTest.DataCase, async: true

  import MetricFlowTest.UsersFixtures

  alias MetricFlow.Accounts.Account
  alias MetricFlow.Ai.Insight
  alias MetricFlow.Ai.SuggestionFeedback
  alias MetricFlow.Repo

  # ---------------------------------------------------------------------------
  # Fixtures
  # ---------------------------------------------------------------------------

  defp new_feedback do
    struct!(SuggestionFeedback, [])
  end

  defp insert_account! do
    user = user_fixture()
    unique = System.unique_integer([:positive])

    %Account{}
    |> Account.creation_changeset(%{
      name: "Test Account #{unique}",
      slug: "test-account-#{unique}",
      type: "personal",
      originator_user_id: user.id
    })
    |> Repo.insert!()
  end

  defp insert_insight!(account_id) do
    %Insight{}
    |> Insight.changeset(%{
      account_id: account_id,
      content: "Increase budget on high-performing campaigns.",
      summary: "Budget increase recommended",
      suggestion_type: :budget_increase,
      confidence: 0.85,
      generated_at: DateTime.utc_now()
    })
    |> Repo.insert!()
  end

  defp insert_feedback!(attrs) do
    new_feedback()
    |> SuggestionFeedback.changeset(attrs)
    |> Repo.insert!()
  end

  defp valid_attrs(insight_id, user_id) do
    %{
      insight_id: insight_id,
      user_id: user_id,
      rating: :helpful,
      comment: nil
    }
  end

  defp long_string(length), do: String.duplicate("a", length)

  # ---------------------------------------------------------------------------
  # changeset/2
  # ---------------------------------------------------------------------------

  describe "changeset/2" do
    test "creates valid changeset with all required fields and a :helpful rating" do
      account = insert_account!()
      insight = insert_insight!(account.id)
      user = user_fixture()
      attrs = valid_attrs(insight.id, user.id)

      changeset = SuggestionFeedback.changeset(new_feedback(), attrs)

      assert changeset.valid?
    end

    test "creates valid changeset with a :not_helpful rating" do
      account = insert_account!()
      insight = insert_insight!(account.id)
      user = user_fixture()
      attrs = %{valid_attrs(insight.id, user.id) | rating: :not_helpful}

      changeset = SuggestionFeedback.changeset(new_feedback(), attrs)

      assert changeset.valid?
    end

    test "validates insight_id is required" do
      user = user_fixture()
      attrs = %{user_id: user.id, rating: :helpful}

      changeset = SuggestionFeedback.changeset(new_feedback(), attrs)

      refute changeset.valid?
      assert %{insight_id: ["can't be blank"]} = errors_on(changeset)
    end

    test "validates user_id is required" do
      account = insert_account!()
      insight = insert_insight!(account.id)
      attrs = %{insight_id: insight.id, rating: :helpful}

      changeset = SuggestionFeedback.changeset(new_feedback(), attrs)

      refute changeset.valid?
      assert %{user_id: ["can't be blank"]} = errors_on(changeset)
    end

    test "validates rating is required" do
      account = insert_account!()
      insight = insert_insight!(account.id)
      user = user_fixture()
      attrs = %{insight_id: insight.id, user_id: user.id}

      changeset = SuggestionFeedback.changeset(new_feedback(), attrs)

      refute changeset.valid?
      assert %{rating: ["can't be blank"]} = errors_on(changeset)
    end

    test "rejects invalid rating values not in the enum" do
      account = insert_account!()
      insight = insert_insight!(account.id)
      user = user_fixture()
      attrs = %{insight_id: insight.id, user_id: user.id, rating: :unknown}

      changeset = SuggestionFeedback.changeset(new_feedback(), attrs)

      refute changeset.valid?
      assert %{rating: [_]} = errors_on(changeset)
    end

    test "allows nil comment (optional field)" do
      account = insert_account!()
      insight = insert_insight!(account.id)
      user = user_fixture()
      attrs = Map.put(valid_attrs(insight.id, user.id), :comment, nil)

      changeset = SuggestionFeedback.changeset(new_feedback(), attrs)

      assert changeset.valid?
    end

    test "accepts a non-nil comment up to 1000 characters" do
      account = insert_account!()
      insight = insert_insight!(account.id)
      user = user_fixture()
      attrs = Map.put(valid_attrs(insight.id, user.id), :comment, long_string(1000))

      changeset = SuggestionFeedback.changeset(new_feedback(), attrs)

      assert changeset.valid?
    end

    test "rejects comment exceeding 1000 characters" do
      account = insert_account!()
      insight = insert_insight!(account.id)
      user = user_fixture()
      attrs = Map.put(valid_attrs(insight.id, user.id), :comment, long_string(1001))

      changeset = SuggestionFeedback.changeset(new_feedback(), attrs)

      refute changeset.valid?
      assert %{comment: [_]} = errors_on(changeset)
    end

    test "validates insight association exists (assoc_constraint triggers on insert)" do
      user = user_fixture()
      attrs = %{insight_id: -1, user_id: user.id, rating: :helpful}

      {:error, changeset} =
        new_feedback()
        |> SuggestionFeedback.changeset(attrs)
        |> Repo.insert()

      assert %{insight: ["does not exist"]} = errors_on(changeset)
    end

    test "validates user association exists (assoc_constraint triggers on insert)" do
      account = insert_account!()
      insight = insert_insight!(account.id)
      attrs = %{insight_id: insight.id, user_id: -1, rating: :helpful}

      {:error, changeset} =
        new_feedback()
        |> SuggestionFeedback.changeset(attrs)
        |> Repo.insert()

      assert %{user: ["does not exist"]} = errors_on(changeset)
    end

    test "enforces uniqueness on [insight_id, user_id]" do
      account = insert_account!()
      insight = insert_insight!(account.id)
      user = user_fixture()
      attrs = valid_attrs(insight.id, user.id)

      _first = insert_feedback!(attrs)

      {:error, changeset} =
        new_feedback()
        |> SuggestionFeedback.changeset(attrs)
        |> Repo.insert()

      assert %{insight_id: ["has already been taken"]} = errors_on(changeset)
    end

    test "allows same insight_id with different user_id values" do
      account = insert_account!()
      insight = insert_insight!(account.id)
      user_one = user_fixture()
      user_two = user_fixture()

      attrs_one = valid_attrs(insight.id, user_one.id)
      _first = insert_feedback!(attrs_one)

      attrs_two = valid_attrs(insight.id, user_two.id)
      changeset = SuggestionFeedback.changeset(new_feedback(), attrs_two)

      assert changeset.valid?
    end

    test "allows same user_id with different insight_id values" do
      account = insert_account!()
      insight_one = insert_insight!(account.id)
      insight_two = insert_insight!(account.id)
      user = user_fixture()

      attrs_one = valid_attrs(insight_one.id, user.id)
      _first = insert_feedback!(attrs_one)

      attrs_two = valid_attrs(insight_two.id, user.id)
      changeset = SuggestionFeedback.changeset(new_feedback(), attrs_two)

      assert changeset.valid?
    end
  end

  # ---------------------------------------------------------------------------
  # helpful?/1
  # ---------------------------------------------------------------------------

  describe "helpful?/1" do
    test "returns true when rating is :helpful" do
      feedback = %SuggestionFeedback{rating: :helpful}

      assert SuggestionFeedback.helpful?(feedback)
    end

    test "returns false when rating is :not_helpful" do
      feedback = %SuggestionFeedback{rating: :not_helpful}

      refute SuggestionFeedback.helpful?(feedback)
    end
  end
end
