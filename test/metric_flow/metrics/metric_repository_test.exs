defmodule MetricFlow.Metrics.MetricRepositoryTest do
  use MetricFlowTest.DataCase, async: true

  import MetricFlowTest.UsersFixtures

  alias MetricFlow.Metrics.Metric
  alias MetricFlow.Metrics.MetricRepository
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

  defp valid_recorded_at(offset_days \\ 0) do
    DateTime.utc_now()
    |> DateTime.add(-offset_days * 86_400, :second)
    |> DateTime.truncate(:microsecond)
  end

  defp valid_metric_attrs(user_id, overrides \\ %{}) do
    Map.merge(
      %{
        user_id: user_id,
        metric_type: "traffic",
        metric_name: "sessions",
        value: 100.0,
        recorded_at: valid_recorded_at(),
        provider: :google_analytics,
        dimensions: %{"source" => "organic"}
      },
      overrides
    )
  end

  defp insert_metric!(user_id, overrides \\ %{}) do
    attrs = valid_metric_attrs(user_id, overrides)

    %Metric{}
    |> Metric.changeset(attrs)
    |> Repo.insert!()
  end

  # ---------------------------------------------------------------------------
  # list_metrics/2
  # ---------------------------------------------------------------------------

  describe "list_metrics/2" do
    test "returns list of metrics for scoped user" do
      {user, scope} = user_with_scope()
      insert_metric!(user.id)
      insert_metric!(user.id, %{metric_name: "pageviews"})

      results = MetricRepository.list_metrics(scope)

      assert length(results) == 2
    end

    test "returns empty list when user has no metrics" do
      {_user, scope} = user_with_scope()

      assert MetricRepository.list_metrics(scope) == []
    end

    test "filters by provider when provider option is provided" do
      {user, scope} = user_with_scope()
      insert_metric!(user.id, %{provider: :google_analytics})
      insert_metric!(user.id, %{provider: :google_ads, metric_name: "clicks"})

      results = MetricRepository.list_metrics(scope, provider: :google_analytics)

      assert length(results) == 1
      assert hd(results).provider == :google_analytics
    end

    test "filters by metric_type when metric_type option is provided" do
      {user, scope} = user_with_scope()
      insert_metric!(user.id, %{metric_type: "traffic"})
      insert_metric!(user.id, %{metric_type: "advertising", metric_name: "clicks"})

      results = MetricRepository.list_metrics(scope, metric_type: "traffic")

      assert length(results) == 1
      assert hd(results).metric_type == "traffic"
    end

    test "filters by metric_name when metric_name option is provided" do
      {user, scope} = user_with_scope()
      insert_metric!(user.id, %{metric_name: "sessions"})
      insert_metric!(user.id, %{metric_name: "pageviews"})

      results = MetricRepository.list_metrics(scope, metric_name: "sessions")

      assert length(results) == 1
      assert hd(results).metric_name == "sessions"
    end

    test "filters by date range when date_range option is provided as {start_date, end_date}" do
      {user, scope} = user_with_scope()
      in_range_at = valid_recorded_at(5)
      out_of_range_at = valid_recorded_at(20)

      insert_metric!(user.id, %{recorded_at: in_range_at})
      insert_metric!(user.id, %{metric_name: "pageviews", recorded_at: out_of_range_at})

      start_date = Date.utc_today() |> Date.add(-10)
      end_date = Date.utc_today()

      results = MetricRepository.list_metrics(scope, date_range: {start_date, end_date})

      assert length(results) == 1
      assert hd(results).metric_name == "sessions"
    end

    test "applies limit when limit option is provided" do
      {user, scope} = user_with_scope()
      insert_metric!(user.id)
      insert_metric!(user.id, %{metric_name: "pageviews"})
      insert_metric!(user.id, %{metric_name: "bounces"})

      results = MetricRepository.list_metrics(scope, limit: 2)

      assert length(results) == 2
    end

    test "applies offset when offset option is provided" do
      {user, scope} = user_with_scope()
      insert_metric!(user.id, %{value: 1.0, recorded_at: valid_recorded_at(3)})
      insert_metric!(user.id, %{value: 2.0, recorded_at: valid_recorded_at(2)})
      insert_metric!(user.id, %{value: 3.0, recorded_at: valid_recorded_at(1)})

      results = MetricRepository.list_metrics(scope, offset: 1)

      assert length(results) == 2
    end

    test "metrics are ordered by recorded_at descending" do
      {user, scope} = user_with_scope()
      older = insert_metric!(user.id, %{recorded_at: valid_recorded_at(5)})
      newer = insert_metric!(user.id, %{recorded_at: valid_recorded_at(1)})

      results = MetricRepository.list_metrics(scope)
      result_ids = Enum.map(results, & &1.id)

      assert result_ids == [newer.id, older.id]
    end

    test "does not return metrics belonging to other users" do
      {user, scope} = user_with_scope()
      {other_user, _other_scope} = user_with_scope()

      insert_metric!(user.id)
      insert_metric!(other_user.id, %{metric_name: "pageviews"})

      results = MetricRepository.list_metrics(scope)

      assert length(results) == 1
      assert hd(results).user_id == user.id
    end

    test "enforces multi-tenant isolation" do
      {user_a, scope_a} = user_with_scope()
      {user_b, _scope_b} = user_with_scope()

      insert_metric!(user_a.id, %{value: 10.0})
      insert_metric!(user_b.id, %{value: 20.0})
      insert_metric!(user_b.id, %{metric_name: "pageviews", value: 30.0})

      results = MetricRepository.list_metrics(scope_a)

      assert length(results) == 1
      assert hd(results).user_id == user_a.id
    end
  end

  # ---------------------------------------------------------------------------
  # get_metric/2
  # ---------------------------------------------------------------------------

  describe "get_metric/2" do
    test "returns ok tuple with metric when metric exists for scoped user" do
      {user, scope} = user_with_scope()
      metric = insert_metric!(user.id)

      assert {:ok, result} = MetricRepository.get_metric(scope, metric.id)
      assert result.id == metric.id
    end

    test "returns error tuple with :not_found when metric id does not exist" do
      {_user, scope} = user_with_scope()

      assert {:error, :not_found} = MetricRepository.get_metric(scope, -1)
    end

    test "returns error tuple with :not_found when metric belongs to a different user" do
      {other_user, _other_scope} = user_with_scope()
      metric = insert_metric!(other_user.id)

      {_user, scope} = user_with_scope()

      assert {:error, :not_found} = MetricRepository.get_metric(scope, metric.id)
    end

    test "enforces multi-tenant isolation" do
      {user_a, scope_a} = user_with_scope()
      {user_b, _scope_b} = user_with_scope()

      metric_a = insert_metric!(user_a.id)
      metric_b = insert_metric!(user_b.id)

      assert {:ok, result} = MetricRepository.get_metric(scope_a, metric_a.id)
      assert result.user_id == user_a.id

      assert {:error, :not_found} = MetricRepository.get_metric(scope_a, metric_b.id)
    end
  end

  # ---------------------------------------------------------------------------
  # create_metric/2
  # ---------------------------------------------------------------------------

  describe "create_metric/2" do
    test "creates metric record with valid attributes" do
      {user, scope} = user_with_scope()
      attrs = Map.delete(valid_metric_attrs(user.id), :user_id)

      assert {:ok, metric} = MetricRepository.create_metric(scope, attrs)
      assert metric.id != nil
    end

    test "associates metric with user_id from scope" do
      {user, scope} = user_with_scope()
      attrs = Map.delete(valid_metric_attrs(user.id), :user_id)

      assert {:ok, metric} = MetricRepository.create_metric(scope, attrs)
      assert metric.user_id == user.id
    end

    test "stores metric_type, metric_name, value, recorded_at, and provider" do
      {_user, scope} = user_with_scope()
      recorded_at = valid_recorded_at()

      attrs = %{
        metric_type: "advertising",
        metric_name: "clicks",
        value: 42.5,
        recorded_at: recorded_at,
        provider: :google_ads
      }

      assert {:ok, metric} = MetricRepository.create_metric(scope, attrs)
      assert metric.metric_type == "advertising"
      assert metric.metric_name == "clicks"
      assert metric.value == 42.5
      assert metric.provider == :google_ads
    end

    test "stores dimensions as embedded map" do
      {user, scope} = user_with_scope()
      dimensions = %{"campaign" => "spring_sale", "ad_group" => "group_1"}
      attrs = Map.merge(Map.delete(valid_metric_attrs(user.id), :user_id), %{dimensions: dimensions})

      assert {:ok, metric} = MetricRepository.create_metric(scope, attrs)
      assert metric.dimensions == dimensions
    end

    test "returns error changeset when metric_type is missing" do
      {user, scope} = user_with_scope()
      attrs = Map.delete(valid_metric_attrs(user.id), :metric_type) |> Map.delete(:user_id)

      assert {:error, changeset} = MetricRepository.create_metric(scope, attrs)
      refute changeset.valid?
      assert %{metric_type: ["can't be blank"]} = errors_on(changeset)
    end

    test "returns error changeset when metric_name is missing" do
      {user, scope} = user_with_scope()
      attrs = Map.delete(valid_metric_attrs(user.id), :metric_name) |> Map.delete(:user_id)

      assert {:error, changeset} = MetricRepository.create_metric(scope, attrs)
      refute changeset.valid?
      assert %{metric_name: ["can't be blank"]} = errors_on(changeset)
    end

    test "returns error changeset when value is missing" do
      {user, scope} = user_with_scope()
      attrs = Map.delete(valid_metric_attrs(user.id), :value) |> Map.delete(:user_id)

      assert {:error, changeset} = MetricRepository.create_metric(scope, attrs)
      refute changeset.valid?
      assert %{value: ["can't be blank"]} = errors_on(changeset)
    end

    test "returns error changeset when provider is missing" do
      {user, scope} = user_with_scope()
      attrs = Map.delete(valid_metric_attrs(user.id), :provider) |> Map.delete(:user_id)

      assert {:error, changeset} = MetricRepository.create_metric(scope, attrs)
      refute changeset.valid?
      assert %{provider: ["can't be blank"]} = errors_on(changeset)
    end

    test "returns error changeset when recorded_at is missing" do
      {user, scope} = user_with_scope()
      attrs = Map.delete(valid_metric_attrs(user.id), :recorded_at) |> Map.delete(:user_id)

      assert {:error, changeset} = MetricRepository.create_metric(scope, attrs)
      refute changeset.valid?
      assert %{recorded_at: ["can't be blank"]} = errors_on(changeset)
    end

    test "does not allow inserting metrics for a different user than the scope" do
      {_user, scope} = user_with_scope()
      {other_user, _other_scope} = user_with_scope()

      attrs = Map.delete(valid_metric_attrs(other_user.id), :user_id)

      assert {:ok, metric} = MetricRepository.create_metric(scope, attrs)
      assert metric.user_id == scope.user.id
      assert metric.user_id != other_user.id
    end
  end

  # ---------------------------------------------------------------------------
  # create_metrics/2
  # ---------------------------------------------------------------------------

  describe "create_metrics/2" do
    test "returns ok tuple with count of inserted metrics" do
      {user, scope} = user_with_scope()

      attrs_list = [
        Map.delete(valid_metric_attrs(user.id, %{metric_name: "sessions"}), :user_id),
        Map.delete(valid_metric_attrs(user.id, %{metric_name: "pageviews"}), :user_id)
      ]

      assert {:ok, 2} = MetricRepository.create_metrics(scope, attrs_list)
    end

    test "associates all metrics with user_id from scope" do
      {user, scope} = user_with_scope()

      attrs_list = [
        Map.delete(valid_metric_attrs(user.id, %{metric_name: "sessions"}), :user_id),
        Map.delete(valid_metric_attrs(user.id, %{metric_name: "pageviews"}), :user_id)
      ]

      {:ok, _count} = MetricRepository.create_metrics(scope, attrs_list)

      inserted = Repo.all(Metric)
      assert Enum.all?(inserted, &(&1.user_id == user.id))
    end

    test "inserts all metrics in a single database operation" do
      {user, scope} = user_with_scope()

      attrs_list =
        Enum.map(1..5, fn i ->
          Map.delete(valid_metric_attrs(user.id, %{metric_name: "metric_#{i}", value: i * 1.0}), :user_id)
        end)

      assert {:ok, 5} = MetricRepository.create_metrics(scope, attrs_list)
      assert Repo.aggregate(Metric, :count) == 5
    end

    test "returns {:ok, 0} for empty list input" do
      {_user, scope} = user_with_scope()

      assert {:ok, 0} = MetricRepository.create_metrics(scope, [])
    end

    test "sets inserted_at and updated_at timestamps on all inserted records" do
      {user, scope} = user_with_scope()

      attrs_list = [
        Map.delete(valid_metric_attrs(user.id, %{metric_name: "sessions"}), :user_id)
      ]

      {:ok, _count} = MetricRepository.create_metrics(scope, attrs_list)

      inserted = Repo.all(Metric)
      assert Enum.all?(inserted, &(&1.inserted_at != nil))
      assert Enum.all?(inserted, &(&1.updated_at != nil))
    end

    test "does not insert any records when the list is empty" do
      {_user, scope} = user_with_scope()

      {:ok, _} = MetricRepository.create_metrics(scope, [])

      assert Repo.aggregate(Metric, :count) == 0
    end
  end

  # ---------------------------------------------------------------------------
  # delete_metrics_by_provider/2
  # ---------------------------------------------------------------------------

  describe "delete_metrics_by_provider/2" do
    test "returns ok tuple with count of deleted metrics" do
      {user, scope} = user_with_scope()
      insert_metric!(user.id, %{provider: :google_analytics})
      insert_metric!(user.id, %{provider: :google_analytics, metric_name: "pageviews"})

      assert {:ok, 2} = MetricRepository.delete_metrics_by_provider(scope, :google_analytics)
    end

    test "deletes only metrics matching the specified provider for the scoped user" do
      {user, scope} = user_with_scope()
      insert_metric!(user.id, %{provider: :google_analytics})
      insert_metric!(user.id, %{provider: :google_ads, metric_name: "clicks"})

      {:ok, _count} = MetricRepository.delete_metrics_by_provider(scope, :google_analytics)

      remaining = Repo.all(Metric)
      assert length(remaining) == 1
      assert hd(remaining).provider == :google_ads
    end

    test "does not delete metrics from other providers" do
      {user, scope} = user_with_scope()
      insert_metric!(user.id, %{provider: :google_analytics})
      ads_metric = insert_metric!(user.id, %{provider: :google_ads, metric_name: "clicks"})

      {:ok, _count} = MetricRepository.delete_metrics_by_provider(scope, :google_analytics)

      assert Repo.get(Metric, ads_metric.id) != nil
    end

    test "does not delete metrics belonging to other users" do
      {user, scope} = user_with_scope()
      {other_user, _other_scope} = user_with_scope()

      insert_metric!(user.id, %{provider: :google_analytics})
      other_metric = insert_metric!(other_user.id, %{provider: :google_analytics})

      {:ok, _count} = MetricRepository.delete_metrics_by_provider(scope, :google_analytics)

      assert Repo.get(Metric, other_metric.id) != nil
    end

    test "returns {:ok, 0} when no metrics match the provider" do
      {_user, scope} = user_with_scope()

      assert {:ok, 0} = MetricRepository.delete_metrics_by_provider(scope, :google_analytics)
    end

    test "enforces multi-tenant isolation" do
      {user_a, scope_a} = user_with_scope()
      {user_b, _scope_b} = user_with_scope()

      insert_metric!(user_a.id, %{provider: :google_analytics})
      other_metric = insert_metric!(user_b.id, %{provider: :google_analytics})

      {:ok, count} = MetricRepository.delete_metrics_by_provider(scope_a, :google_analytics)

      assert count == 1
      assert Repo.get(Metric, other_metric.id) != nil
    end
  end

  # ---------------------------------------------------------------------------
  # query_time_series/3
  # ---------------------------------------------------------------------------

  describe "query_time_series/3" do
    test "returns list of date/value maps for matching metrics" do
      {user, scope} = user_with_scope()
      insert_metric!(user.id, %{metric_name: "sessions", value: 50.0, recorded_at: valid_recorded_at(1)})

      results = MetricRepository.query_time_series(scope, "sessions", [])

      assert results != []
      assert %{date: _, value: _} = hd(results)
    end

    test "groups values by date and sums them within each date" do
      {user, scope} = user_with_scope()
      same_day = valid_recorded_at(1)

      insert_metric!(user.id, %{metric_name: "sessions", value: 30.0, recorded_at: same_day})
      insert_metric!(user.id, %{metric_name: "sessions", value: 70.0, recorded_at: same_day})

      results = MetricRepository.query_time_series(scope, "sessions", [])

      assert length(results) == 1
      assert hd(results).value == 100.0
    end

    test "orders results by date ascending" do
      {user, scope} = user_with_scope()

      insert_metric!(user.id, %{metric_name: "sessions", value: 10.0, recorded_at: valid_recorded_at(3)})
      insert_metric!(user.id, %{metric_name: "sessions", value: 20.0, recorded_at: valid_recorded_at(2)})
      insert_metric!(user.id, %{metric_name: "sessions", value: 30.0, recorded_at: valid_recorded_at(1)})

      results = MetricRepository.query_time_series(scope, "sessions", [])

      dates = Enum.map(results, & &1.date)
      assert dates == Enum.sort(dates, Date)
    end

    test "filters by provider when provider option is provided" do
      {user, scope} = user_with_scope()

      insert_metric!(user.id, %{
        metric_name: "sessions",
        provider: :google_analytics,
        value: 100.0,
        recorded_at: valid_recorded_at(1)
      })

      insert_metric!(user.id, %{
        metric_name: "sessions",
        provider: :google_ads,
        value: 200.0,
        recorded_at: valid_recorded_at(1)
      })

      results = MetricRepository.query_time_series(scope, "sessions", provider: :google_analytics)

      assert length(results) == 1
      assert hd(results).value == 100.0
    end

    test "defaults to last 30 days when date_range option is not provided" do
      {user, scope} = user_with_scope()

      insert_metric!(user.id, %{
        metric_name: "sessions",
        value: 10.0,
        recorded_at: valid_recorded_at(5)
      })

      insert_metric!(user.id, %{
        metric_name: "sessions",
        value: 20.0,
        recorded_at: valid_recorded_at(40)
      })

      results = MetricRepository.query_time_series(scope, "sessions", [])

      assert length(results) == 1
      assert hd(results).value == 10.0
    end

    test "filters by date range when date_range option is provided as {start_date, end_date}" do
      {user, scope} = user_with_scope()

      insert_metric!(user.id, %{
        metric_name: "sessions",
        value: 10.0,
        recorded_at: valid_recorded_at(5)
      })

      insert_metric!(user.id, %{
        metric_name: "sessions",
        value: 20.0,
        recorded_at: valid_recorded_at(20)
      })

      start_date = Date.utc_today() |> Date.add(-10)
      end_date = Date.utc_today()

      results = MetricRepository.query_time_series(scope, "sessions", date_range: {start_date, end_date})

      assert length(results) == 1
      assert hd(results).value == 10.0
    end

    test "returns empty list when no matching metrics are found" do
      {_user, scope} = user_with_scope()

      assert MetricRepository.query_time_series(scope, "nonexistent_metric", []) == []
    end

    test "does not include metrics from other users" do
      {user, scope} = user_with_scope()
      {other_user, _other_scope} = user_with_scope()

      insert_metric!(user.id, %{metric_name: "sessions", value: 10.0, recorded_at: valid_recorded_at(1)})
      insert_metric!(other_user.id, %{metric_name: "sessions", value: 999.0, recorded_at: valid_recorded_at(1)})

      results = MetricRepository.query_time_series(scope, "sessions", [])

      assert length(results) == 1
      assert hd(results).value == 10.0
    end

    test "enforces multi-tenant isolation" do
      {user_a, scope_a} = user_with_scope()
      {user_b, _scope_b} = user_with_scope()

      insert_metric!(user_a.id, %{metric_name: "sessions", value: 5.0, recorded_at: valid_recorded_at(1)})
      insert_metric!(user_b.id, %{metric_name: "sessions", value: 500.0, recorded_at: valid_recorded_at(1)})

      results = MetricRepository.query_time_series(scope_a, "sessions", [])

      assert length(results) == 1
      assert hd(results).value == 5.0
    end
  end

  # ---------------------------------------------------------------------------
  # aggregate_metrics/3
  # ---------------------------------------------------------------------------

  describe "aggregate_metrics/3" do
    test "returns map with sum, avg, min, max, and count keys" do
      {user, scope} = user_with_scope()
      insert_metric!(user.id, %{metric_name: "sessions", value: 10.0})

      result = MetricRepository.aggregate_metrics(scope, "sessions", [])

      assert Map.has_key?(result, :sum)
      assert Map.has_key?(result, :avg)
      assert Map.has_key?(result, :min)
      assert Map.has_key?(result, :max)
      assert Map.has_key?(result, :count)
    end

    test "calculates correct sum of metric values" do
      {user, scope} = user_with_scope()
      insert_metric!(user.id, %{metric_name: "sessions", value: 30.0})
      insert_metric!(user.id, %{metric_name: "sessions", value: 70.0})

      result = MetricRepository.aggregate_metrics(scope, "sessions", [])

      assert result.sum == 100.0
    end

    test "calculates correct average of metric values" do
      {user, scope} = user_with_scope()
      insert_metric!(user.id, %{metric_name: "sessions", value: 20.0})
      insert_metric!(user.id, %{metric_name: "sessions", value: 40.0})

      result = MetricRepository.aggregate_metrics(scope, "sessions", [])

      assert result.avg == 30.0
    end

    test "returns correct min and max values" do
      {user, scope} = user_with_scope()
      insert_metric!(user.id, %{metric_name: "sessions", value: 5.0})
      insert_metric!(user.id, %{metric_name: "sessions", value: 15.0})
      insert_metric!(user.id, %{metric_name: "sessions", value: 25.0})

      result = MetricRepository.aggregate_metrics(scope, "sessions", [])

      assert result.min == 5.0
      assert result.max == 25.0
    end

    test "returns correct count of matching records" do
      {user, scope} = user_with_scope()
      insert_metric!(user.id, %{metric_name: "sessions", value: 10.0})
      insert_metric!(user.id, %{metric_name: "sessions", value: 20.0})
      insert_metric!(user.id, %{metric_name: "pageviews", value: 30.0})

      result = MetricRepository.aggregate_metrics(scope, "sessions", [])

      assert result.count == 2
    end

    test "filters by provider when provider option is provided" do
      {user, scope} = user_with_scope()
      insert_metric!(user.id, %{metric_name: "sessions", provider: :google_analytics, value: 10.0})
      insert_metric!(user.id, %{metric_name: "sessions", provider: :google_ads, value: 90.0})

      result = MetricRepository.aggregate_metrics(scope, "sessions", provider: :google_analytics)

      assert result.sum == 10.0
      assert result.count == 1
    end

    test "filters by date range when date_range option is provided" do
      {user, scope} = user_with_scope()

      insert_metric!(user.id, %{metric_name: "sessions", value: 10.0, recorded_at: valid_recorded_at(5)})
      insert_metric!(user.id, %{metric_name: "sessions", value: 90.0, recorded_at: valid_recorded_at(20)})

      start_date = Date.utc_today() |> Date.add(-10)
      end_date = Date.utc_today()

      result = MetricRepository.aggregate_metrics(scope, "sessions", date_range: {start_date, end_date})

      assert result.sum == 10.0
      assert result.count == 1
    end

    test "returns zeroed map when no matching metrics are found" do
      {_user, scope} = user_with_scope()

      result = MetricRepository.aggregate_metrics(scope, "nonexistent_metric", [])

      assert result == %{sum: 0.0, avg: 0.0, min: 0.0, max: 0.0, count: 0}
    end

    test "does not include metrics from other users" do
      {user, scope} = user_with_scope()
      {other_user, _other_scope} = user_with_scope()

      insert_metric!(user.id, %{metric_name: "sessions", value: 10.0})
      insert_metric!(other_user.id, %{metric_name: "sessions", value: 1000.0})

      result = MetricRepository.aggregate_metrics(scope, "sessions", [])

      assert result.sum == 10.0
      assert result.count == 1
    end

    test "enforces multi-tenant isolation" do
      {user_a, scope_a} = user_with_scope()
      {user_b, _scope_b} = user_with_scope()

      insert_metric!(user_a.id, %{metric_name: "sessions", value: 5.0})
      insert_metric!(user_b.id, %{metric_name: "sessions", value: 500.0})

      result = MetricRepository.aggregate_metrics(scope_a, "sessions", [])

      assert result.sum == 5.0
      assert result.max == 5.0
      assert result.count == 1
    end
  end

  # ---------------------------------------------------------------------------
  # list_metric_names/2
  # ---------------------------------------------------------------------------

  describe "list_metric_names/2" do
    test "returns list of distinct metric names for scoped user" do
      {user, scope} = user_with_scope()
      insert_metric!(user.id, %{metric_name: "sessions"})
      insert_metric!(user.id, %{metric_name: "pageviews"})

      results = MetricRepository.list_metric_names(scope)

      assert "sessions" in results
      assert "pageviews" in results
    end

    test "does not contain duplicate metric names" do
      {user, scope} = user_with_scope()
      insert_metric!(user.id, %{metric_name: "sessions", value: 10.0})
      insert_metric!(user.id, %{metric_name: "sessions", value: 20.0})

      results = MetricRepository.list_metric_names(scope)

      assert results == Enum.uniq(results)
      assert length(results) == 1
    end

    test "filters by provider when provider option is provided" do
      {user, scope} = user_with_scope()
      insert_metric!(user.id, %{metric_name: "sessions", provider: :google_analytics})
      insert_metric!(user.id, %{metric_name: "clicks", provider: :google_ads})

      results = MetricRepository.list_metric_names(scope, provider: :google_analytics)

      assert results == ["sessions"]
    end

    test "returns empty list when user has no metrics" do
      {_user, scope} = user_with_scope()

      assert MetricRepository.list_metric_names(scope) == []
    end

    test "orders names alphabetically" do
      {user, scope} = user_with_scope()
      insert_metric!(user.id, %{metric_name: "sessions"})
      insert_metric!(user.id, %{metric_name: "pageviews"})
      insert_metric!(user.id, %{metric_name: "bounces"})

      results = MetricRepository.list_metric_names(scope)

      assert results == Enum.sort(results)
    end

    test "does not include metric names from other users" do
      {user, scope} = user_with_scope()
      {other_user, _other_scope} = user_with_scope()

      insert_metric!(user.id, %{metric_name: "sessions"})
      insert_metric!(other_user.id, %{metric_name: "revenue"})

      results = MetricRepository.list_metric_names(scope)

      assert "sessions" in results
      refute "revenue" in results
    end

    test "enforces multi-tenant isolation" do
      {user_a, scope_a} = user_with_scope()
      {user_b, _scope_b} = user_with_scope()

      insert_metric!(user_a.id, %{metric_name: "sessions"})
      insert_metric!(user_b.id, %{metric_name: "revenue"})
      insert_metric!(user_b.id, %{metric_name: "clicks"})

      results = MetricRepository.list_metric_names(scope_a)

      assert results == ["sessions"]
    end
  end
end
