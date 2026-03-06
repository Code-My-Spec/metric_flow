defmodule MetricFlow.Ai.InsightTest do
  use MetricFlowTest.DataCase, async: true

  import MetricFlowTest.UsersFixtures

  alias MetricFlow.Accounts.Account
  alias MetricFlow.Accounts.AccountMember
  alias MetricFlow.Ai.Insight
  alias MetricFlow.Correlations.CorrelationJob
  alias MetricFlow.Correlations.CorrelationResult
  alias MetricFlow.Repo

  # ---------------------------------------------------------------------------
  # Fixtures
  # ---------------------------------------------------------------------------

  defp unique_slug, do: "account-#{System.unique_integer([:positive])}"

  defp create_account! do
    user = user_fixture()

    {:ok, account} =
      %Account{}
      |> Account.creation_changeset(%{
        name: "#{user.email} Personal",
        slug: unique_slug(),
        type: "personal",
        originator_user_id: user.id
      })
      |> Repo.insert()

    %AccountMember{}
    |> AccountMember.changeset(%{
      account_id: account.id,
      user_id: user.id,
      role: :owner
    })
    |> Repo.insert!()

    account
  end

  defp create_correlation_result!(account_id) do
    {:ok, job} =
      %CorrelationJob{}
      |> CorrelationJob.changeset(%{
        account_id: account_id,
        status: :completed,
        goal_metric_name: "revenue"
      })
      |> Repo.insert()

    {:ok, result} =
      %CorrelationResult{}
      |> CorrelationResult.changeset(%{
        account_id: account_id,
        correlation_job_id: job.id,
        metric_name: "sessions",
        goal_metric_name: "revenue",
        coefficient: 0.85,
        optimal_lag: 3,
        data_points: 90,
        calculated_at: DateTime.utc_now()
      })
      |> Repo.insert()

    result
  end

  defp valid_attrs(account_id, overrides \\ %{}) do
    Map.merge(
      %{
        account_id: account_id,
        content: "Increasing budget on Google Ads campaigns targeting high-intent keywords could improve revenue.",
        summary: "Increase Google Ads budget to improve revenue",
        suggestion_type: :budget_increase,
        confidence: 0.85,
        generated_at: DateTime.utc_now()
      },
      overrides
    )
  end

  # ---------------------------------------------------------------------------
  # changeset/2
  # ---------------------------------------------------------------------------

  describe "changeset/2" do
    test "creates valid changeset with all required fields" do
      account = create_account!()
      attrs = valid_attrs(account.id)

      changeset = Insight.changeset(%Insight{}, attrs)

      assert changeset.valid?
    end

    test "validates account_id is required" do
      attrs = valid_attrs(nil) |> Map.delete(:account_id)

      changeset = Insight.changeset(%Insight{}, attrs)

      refute changeset.valid?
      assert errors_on(changeset)[:account_id] != nil
    end

    test "validates content is required" do
      account = create_account!()
      attrs = valid_attrs(account.id) |> Map.delete(:content)

      changeset = Insight.changeset(%Insight{}, attrs)

      refute changeset.valid?
      assert errors_on(changeset)[:content] != nil
    end

    test "validates summary is required" do
      account = create_account!()
      attrs = valid_attrs(account.id) |> Map.delete(:summary)

      changeset = Insight.changeset(%Insight{}, attrs)

      refute changeset.valid?
      assert errors_on(changeset)[:summary] != nil
    end

    test "validates suggestion_type is required" do
      account = create_account!()
      attrs = valid_attrs(account.id) |> Map.delete(:suggestion_type)

      changeset = Insight.changeset(%Insight{}, attrs)

      refute changeset.valid?
      assert errors_on(changeset)[:suggestion_type] != nil
    end

    test "validates confidence is required" do
      account = create_account!()
      attrs = valid_attrs(account.id) |> Map.delete(:confidence)

      changeset = Insight.changeset(%Insight{}, attrs)

      refute changeset.valid?
      assert errors_on(changeset)[:confidence] != nil
    end

    test "validates generated_at is required" do
      account = create_account!()
      attrs = valid_attrs(account.id) |> Map.delete(:generated_at)

      changeset = Insight.changeset(%Insight{}, attrs)

      refute changeset.valid?
      assert errors_on(changeset)[:generated_at] != nil
    end

    test "rejects blank content (empty string)" do
      account = create_account!()
      attrs = valid_attrs(account.id, %{content: ""})

      changeset = Insight.changeset(%Insight{}, attrs)

      refute changeset.valid?
      assert errors_on(changeset)[:content] != nil
    end

    test "rejects summary exceeding 500 characters" do
      account = create_account!()
      long_summary = String.duplicate("a", 501)
      attrs = valid_attrs(account.id, %{summary: long_summary})

      changeset = Insight.changeset(%Insight{}, attrs)

      refute changeset.valid?
      assert errors_on(changeset)[:summary] != nil
    end

    test "accepts summary at exactly 500 characters" do
      account = create_account!()
      max_summary = String.duplicate("a", 500)
      attrs = valid_attrs(account.id, %{summary: max_summary})

      changeset = Insight.changeset(%Insight{}, attrs)

      assert changeset.valid?
    end

    test "rejects confidence below 0.0" do
      account = create_account!()
      attrs = valid_attrs(account.id, %{confidence: -0.1})

      changeset = Insight.changeset(%Insight{}, attrs)

      refute changeset.valid?
      assert errors_on(changeset)[:confidence] != nil
    end

    test "rejects confidence above 1.0" do
      account = create_account!()
      attrs = valid_attrs(account.id, %{confidence: 1.1})

      changeset = Insight.changeset(%Insight{}, attrs)

      refute changeset.valid?
      assert errors_on(changeset)[:confidence] != nil
    end

    test "accepts confidence of exactly 0.0" do
      account = create_account!()
      attrs = valid_attrs(account.id, %{confidence: 0.0})

      changeset = Insight.changeset(%Insight{}, attrs)

      assert changeset.valid?
    end

    test "accepts confidence of exactly 1.0" do
      account = create_account!()
      attrs = valid_attrs(account.id, %{confidence: 1.0})

      changeset = Insight.changeset(%Insight{}, attrs)

      assert changeset.valid?
    end

    test "accepts confidence of exactly 0.7" do
      account = create_account!()
      attrs = valid_attrs(account.id, %{confidence: 0.7})

      changeset = Insight.changeset(%Insight{}, attrs)

      assert changeset.valid?
    end

    test "accepts all valid suggestion_type enum values" do
      account = create_account!()

      for type <- [:budget_increase, :budget_decrease, :optimization, :monitoring, :general] do
        attrs = valid_attrs(account.id, %{suggestion_type: type})
        changeset = Insight.changeset(%Insight{}, attrs)
        assert changeset.valid?, "Expected valid changeset for suggestion_type #{type}"
      end
    end

    test "rejects invalid suggestion_type value" do
      account = create_account!()
      attrs = valid_attrs(account.id, %{suggestion_type: :not_a_type})

      changeset = Insight.changeset(%Insight{}, attrs)

      refute changeset.valid?
      assert errors_on(changeset)[:suggestion_type] != nil
    end

    test "allows nil correlation_result_id as optional" do
      account = create_account!()
      attrs = valid_attrs(account.id, %{correlation_result_id: nil})

      changeset = Insight.changeset(%Insight{}, attrs)

      assert changeset.valid?
    end

    test "accepts correlation_result_id when provided" do
      account = create_account!()
      correlation_result = create_correlation_result!(account.id)
      attrs = valid_attrs(account.id, %{correlation_result_id: correlation_result.id})

      changeset = Insight.changeset(%Insight{}, attrs)

      assert changeset.valid?
    end

    test "defaults metadata to empty map when not provided" do
      account = create_account!()
      attrs = valid_attrs(account.id) |> Map.delete(:metadata)

      changeset = Insight.changeset(%Insight{}, attrs)

      assert changeset.valid?
      # The schema default is %{}, so the struct has it even without casting
      insight = Ecto.Changeset.apply_changes(changeset)
      assert insight.metadata == %{}
    end

    test "validates account association exists" do
      attrs = valid_attrs(0)

      assert {:error, changeset} =
               %Insight{}
               |> Insight.changeset(attrs)
               |> Repo.insert()

      refute changeset.valid?
      assert errors_on(changeset)[:account] != nil
    end

    test "validates correlation_result association exists when correlation_result_id is provided" do
      account = create_account!()
      attrs = valid_attrs(account.id, %{correlation_result_id: 0})

      assert {:error, changeset} =
               %Insight{}
               |> Insight.changeset(attrs)
               |> Repo.insert()

      refute changeset.valid?
      assert errors_on(changeset)[:correlation_result] != nil
    end
  end

  # ---------------------------------------------------------------------------
  # actionable?/1
  # ---------------------------------------------------------------------------

  describe "actionable?/1" do
    test "returns true for suggestion_type :budget_increase" do
      insight = %Insight{suggestion_type: :budget_increase}
      assert Insight.actionable?(insight) == true
    end

    test "returns true for suggestion_type :budget_decrease" do
      insight = %Insight{suggestion_type: :budget_decrease}
      assert Insight.actionable?(insight) == true
    end

    test "returns true for suggestion_type :optimization" do
      insight = %Insight{suggestion_type: :optimization}
      assert Insight.actionable?(insight) == true
    end

    test "returns false for suggestion_type :monitoring" do
      insight = %Insight{suggestion_type: :monitoring}
      assert Insight.actionable?(insight) == false
    end

    test "returns false for suggestion_type :general" do
      insight = %Insight{suggestion_type: :general}
      assert Insight.actionable?(insight) == false
    end
  end

  # ---------------------------------------------------------------------------
  # high_confidence?/1
  # ---------------------------------------------------------------------------

  describe "high_confidence?/1" do
    test "returns true for confidence of 1.0" do
      insight = %Insight{confidence: 1.0}
      assert Insight.high_confidence?(insight) == true
    end

    test "returns true for confidence of 0.7 (boundary value)" do
      insight = %Insight{confidence: 0.7}
      assert Insight.high_confidence?(insight) == true
    end

    test "returns true for confidence of 0.75" do
      insight = %Insight{confidence: 0.75}
      assert Insight.high_confidence?(insight) == true
    end

    test "returns false for confidence of 0.69" do
      insight = %Insight{confidence: 0.69}
      assert Insight.high_confidence?(insight) == false
    end

    test "returns false for confidence of 0.5" do
      insight = %Insight{confidence: 0.5}
      assert Insight.high_confidence?(insight) == false
    end

    test "returns false for confidence of 0.0" do
      insight = %Insight{confidence: 0.0}
      assert Insight.high_confidence?(insight) == false
    end
  end
end
