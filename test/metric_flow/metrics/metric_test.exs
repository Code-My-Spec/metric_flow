defmodule MetricFlow.Metrics.MetricTest do
  use MetricFlowTest.DataCase, async: true

  import MetricFlowTest.UsersFixtures

  alias MetricFlow.Metrics.Metric
  alias MetricFlow.Repo

  # ---------------------------------------------------------------------------
  # Fixtures
  # ---------------------------------------------------------------------------

  defp valid_recorded_at do
    DateTime.utc_now() |> DateTime.truncate(:microsecond)
  end

  defp valid_attrs(user_id) do
    %{
      user_id: user_id,
      metric_type: "traffic",
      metric_name: "sessions",
      value: 1234.5,
      recorded_at: valid_recorded_at(),
      provider: :google_analytics,
      dimensions: %{"source" => "organic", "page" => "/home"}
    }
  end

  defp new_metric do
    struct!(Metric, [])
  end

  defp insert_metric!(attrs) do
    new_metric()
    |> Metric.changeset(attrs)
    |> Repo.insert!()
  end

  # ---------------------------------------------------------------------------
  # changeset/2
  # ---------------------------------------------------------------------------

  describe "changeset/2" do
    test "creates valid changeset with all required fields" do
      user = user_fixture()
      attrs = valid_attrs(user.id)

      changeset = Metric.changeset(new_metric(), attrs)

      assert changeset.valid?
    end

    test "casts each field attribute correctly (user_id, metric_type, metric_name, value, recorded_at, provider, dimensions)" do
      user = user_fixture()
      recorded_at = valid_recorded_at()

      attrs = %{valid_attrs(user.id) | recorded_at: recorded_at}

      changeset = Metric.changeset(new_metric(), attrs)

      assert get_change(changeset, :user_id) == user.id
      assert get_change(changeset, :metric_type) == "traffic"
      assert get_change(changeset, :metric_name) == "sessions"
      assert get_change(changeset, :value) == 1234.5
      assert get_change(changeset, :recorded_at) == recorded_at
      assert get_change(changeset, :provider) == :google_analytics
      assert get_change(changeset, :dimensions) == %{"source" => "organic", "page" => "/home"}
    end

    test "validates user_id is required" do
      user = user_fixture()
      attrs = Map.delete(valid_attrs(user.id), :user_id)

      changeset = Metric.changeset(new_metric(), attrs)

      refute changeset.valid?
      assert %{user_id: ["can't be blank"]} = errors_on(changeset)
    end

    test "validates metric_type is required" do
      user = user_fixture()
      attrs = Map.delete(valid_attrs(user.id), :metric_type)

      changeset = Metric.changeset(new_metric(), attrs)

      refute changeset.valid?
      assert %{metric_type: ["can't be blank"]} = errors_on(changeset)
    end

    test "validates metric_name is required" do
      user = user_fixture()
      attrs = Map.delete(valid_attrs(user.id), :metric_name)

      changeset = Metric.changeset(new_metric(), attrs)

      refute changeset.valid?
      assert %{metric_name: ["can't be blank"]} = errors_on(changeset)
    end

    test "validates value is required" do
      user = user_fixture()
      attrs = Map.delete(valid_attrs(user.id), :value)

      changeset = Metric.changeset(new_metric(), attrs)

      refute changeset.valid?
      assert %{value: ["can't be blank"]} = errors_on(changeset)
    end

    test "validates recorded_at is required" do
      user = user_fixture()
      attrs = Map.delete(valid_attrs(user.id), :recorded_at)

      changeset = Metric.changeset(new_metric(), attrs)

      refute changeset.valid?
      assert %{recorded_at: ["can't be blank"]} = errors_on(changeset)
    end

    test "validates provider is required" do
      user = user_fixture()
      attrs = Map.delete(valid_attrs(user.id), :provider)

      changeset = Metric.changeset(new_metric(), attrs)

      refute changeset.valid?
      assert %{provider: ["can't be blank"]} = errors_on(changeset)
    end

    test "accepts all valid provider enum values (:google_analytics, :google_ads, :facebook_ads, :quickbooks)" do
      user = user_fixture()

      for provider <- [:google_analytics, :google_ads, :facebook_ads, :quickbooks] do
        attrs = %{valid_attrs(user.id) | provider: provider}
        changeset = Metric.changeset(new_metric(), attrs)

        assert changeset.valid?, "expected #{provider} to be valid"
        assert get_change(changeset, :provider) == provider
      end
    end

    test "rejects unknown provider values" do
      user = user_fixture()
      attrs = %{valid_attrs(user.id) | provider: :unknown_provider}

      changeset = Metric.changeset(new_metric(), attrs)

      refute changeset.valid?
      assert %{provider: [_]} = errors_on(changeset)
    end

    test "allows nil dimensions (defaults to empty map)" do
      user = user_fixture()
      attrs = Map.delete(valid_attrs(user.id), :dimensions)

      changeset = Metric.changeset(new_metric(), attrs)

      assert changeset.valid?
    end

    test "validates dimensions is a map when provided" do
      user = user_fixture()
      attrs = %{valid_attrs(user.id) | dimensions: %{"campaign" => "spring_sale"}}

      changeset = Metric.changeset(new_metric(), attrs)

      assert changeset.valid?
    end

    test "rejects dimensions when not a map" do
      user = user_fixture()
      attrs = %{valid_attrs(user.id) | dimensions: "not-a-map"}

      changeset = Metric.changeset(new_metric(), attrs)

      refute changeset.valid?
      assert %{dimensions: [_]} = errors_on(changeset)
    end

    test "rejects dimensions when it is a list" do
      user = user_fixture()
      attrs = %{valid_attrs(user.id) | dimensions: ["source", "campaign"]}

      changeset = Metric.changeset(new_metric(), attrs)

      refute changeset.valid?
      assert %{dimensions: [_]} = errors_on(changeset)
    end

    test "validates user association exists (assoc_constraint triggers on insert)" do
      attrs = valid_attrs(-1)

      {:error, changeset} =
        new_metric()
        |> Metric.changeset(attrs)
        |> Repo.insert()

      assert %{user: ["does not exist"]} = errors_on(changeset)
    end

    test "creates valid changeset for updating existing metric" do
      user = user_fixture()
      metric = insert_metric!(valid_attrs(user.id))

      new_value = 9999.0
      update_attrs = %{value: new_value}

      changeset = Metric.changeset(metric, update_attrs)

      assert changeset.valid?
      assert get_change(changeset, :value) == new_value
    end

    test "preserves existing fields when updating subset of attributes" do
      user = user_fixture()
      metric = insert_metric!(valid_attrs(user.id))

      update_attrs = %{value: 42.0}
      changeset = Metric.changeset(metric, update_attrs)

      assert changeset.data.metric_type == "traffic"
      assert changeset.data.metric_name == "sessions"
      assert changeset.data.provider == :google_analytics
      assert changeset.data.user_id == user.id
    end

    test "handles empty attributes map gracefully" do
      user = user_fixture()
      metric = insert_metric!(valid_attrs(user.id))

      changeset = Metric.changeset(metric, %{})

      assert changeset.valid?
    end

    test "accepts float value with decimal precision" do
      user = user_fixture()
      attrs = %{valid_attrs(user.id) | value: 3.14159265}

      changeset = Metric.changeset(new_metric(), attrs)

      assert changeset.valid?
      assert get_change(changeset, :value) == 3.14159265
    end

    test "accepts integer value coerced to float" do
      user = user_fixture()
      attrs = %{valid_attrs(user.id) | value: 100}

      changeset = Metric.changeset(new_metric(), attrs)

      assert changeset.valid?
      assert get_change(changeset, :value) == 100.0
    end
  end
end
