defmodule MetricFlow.DashboardsTest do
  use MetricFlowTest.DataCase, async: true

  import MetricFlowTest.UsersFixtures

  alias MetricFlow.Dashboards
  alias MetricFlow.Integrations.Integration
  alias MetricFlow.Metrics.Metric
  alias MetricFlow.Users.Scope

  # ---------------------------------------------------------------------------
  # Fixtures
  # ---------------------------------------------------------------------------

  defp user_with_scope do
    user = user_fixture()
    scope = Scope.for_user(user)
    {user, scope}
  end

  defp valid_recorded_at(offset_days) do
    DateTime.utc_now()
    |> DateTime.add(-offset_days * 86_400, :second)
    |> DateTime.truncate(:microsecond)
  end

  defp insert_metric!(user_id, overrides \\ %{}) do
    defaults = %{
      user_id: user_id,
      metric_type: "traffic",
      metric_name: "sessions",
      value: 100.0,
      recorded_at: valid_recorded_at(1),
      provider: :google_analytics,
      dimensions: %{}
    }

    attrs = Map.merge(defaults, overrides)

    %Metric{}
    |> Metric.changeset(attrs)
    |> Repo.insert!()
  end

  defp insert_integration!(user_id, provider \\ :google, overrides \\ %{}) do
    defaults = %{
      user_id: user_id,
      provider: provider,
      access_token: "access-token-#{System.unique_integer([:positive])}",
      refresh_token: "refresh-token-#{System.unique_integer([:positive])}",
      expires_at: DateTime.add(DateTime.utc_now(), 3_600, :second),
      granted_scopes: ["email", "profile"],
      provider_metadata: %{"provider_user_id" => "stub-user-id"}
    }

    attrs = Map.merge(defaults, overrides)

    %Integration{}
    |> Integration.changeset(attrs)
    |> Repo.insert!()
  end

  # ---------------------------------------------------------------------------
  # get_dashboard_data/2
  # ---------------------------------------------------------------------------

  describe "get_dashboard_data/2" do
    test "returns an ok tuple with a map containing all five keys: time_series, summary_stats, available_filters, connected_platforms, applied_filters" do
      {user, scope} = user_with_scope()
      insert_integration!(user.id)
      insert_metric!(user.id)

      assert {:ok, data} = Dashboards.get_dashboard_data(scope, [])

      assert is_map(data)
      assert Map.has_key?(data, :time_series)
      assert Map.has_key?(data, :summary_stats)
      assert Map.has_key?(data, :available_filters)
      assert Map.has_key?(data, :connected_platforms)
      assert Map.has_key?(data, :applied_filters)
    end

    test "time_series contains one entry per distinct metric name for the scoped user" do
      {user, scope} = user_with_scope()
      insert_integration!(user.id)
      insert_metric!(user.id, %{metric_name: "sessions", value: 10.0})
      insert_metric!(user.id, %{metric_name: "pageviews", value: 20.0})
      insert_metric!(user.id, %{metric_name: "sessions", value: 5.0})

      assert {:ok, %{time_series: time_series}} = Dashboards.get_dashboard_data(scope, [])

      metric_names = Enum.map(time_series, & &1.metric_name)
      assert length(metric_names) == 2
      assert "sessions" in metric_names
      assert "pageviews" in metric_names
    end

    test "summary_stats contains one entry per distinct metric name with sum, avg, min, max, and count keys" do
      {user, scope} = user_with_scope()
      insert_integration!(user.id)
      insert_metric!(user.id, %{metric_name: "sessions", value: 100.0})
      insert_metric!(user.id, %{metric_name: "pageviews", value: 200.0})

      assert {:ok, %{summary_stats: summary_stats}} = Dashboards.get_dashboard_data(scope, [])

      assert length(summary_stats) == 2

      sessions_stats = Enum.find(summary_stats, &(&1.metric_name == "sessions"))
      assert sessions_stats != nil
      assert Map.has_key?(sessions_stats.stats, :sum)
      assert Map.has_key?(sessions_stats.stats, :avg)
      assert Map.has_key?(sessions_stats.stats, :min)
      assert Map.has_key?(sessions_stats.stats, :max)
      assert Map.has_key?(sessions_stats.stats, :count)
    end

    test "connected_platforms reflects the provider atoms of the user's current integrations" do
      {user, scope} = user_with_scope()
      insert_integration!(user.id, :google)

      assert {:ok, %{connected_platforms: platforms}} = Dashboards.get_dashboard_data(scope, [])

      assert :google in platforms
    end

    test "available_filters.platforms is derived from connected integrations" do
      {user, scope} = user_with_scope()
      insert_integration!(user.id, :google)
      insert_metric!(user.id)

      assert {:ok, %{available_filters: filters}} = Dashboards.get_dashboard_data(scope, [])

      assert :google in filters.platforms
    end

    test "available_filters.metric_names contains all distinct metric names for the user" do
      {user, scope} = user_with_scope()
      insert_integration!(user.id)
      insert_metric!(user.id, %{metric_name: "sessions"})
      insert_metric!(user.id, %{metric_name: "pageviews"})

      assert {:ok, %{available_filters: filters}} = Dashboards.get_dashboard_data(scope, [])

      assert "sessions" in filters.metric_names
      assert "pageviews" in filters.metric_names
    end

    test "applies platform filter to both time_series and summary_stats, excluding metrics from other providers" do
      {user, scope} = user_with_scope()
      insert_integration!(user.id, :google)
      insert_metric!(user.id, %{metric_name: "sessions", provider: :google_analytics, value: 50.0})
      insert_metric!(user.id, %{metric_name: "sessions", provider: :google_ads, value: 999.0})

      assert {:ok, data} =
               Dashboards.get_dashboard_data(scope, platform: :google_analytics)

      sessions_ts = Enum.find(data.time_series, &(&1.metric_name == "sessions"))
      total_ts_value = Enum.reduce(sessions_ts.data, 0.0, fn %{value: v}, acc -> acc + v end)
      assert total_ts_value == 50.0

      sessions_stats = Enum.find(data.summary_stats, &(&1.metric_name == "sessions"))
      assert sessions_stats.stats.sum == 50.0
    end

    test "applies date_range filter to both time_series and summary_stats, excluding metrics outside the range" do
      {user, scope} = user_with_scope()
      insert_integration!(user.id)
      insert_metric!(user.id, %{metric_name: "sessions", value: 10.0, recorded_at: valid_recorded_at(5)})
      insert_metric!(user.id, %{metric_name: "sessions", value: 90.0, recorded_at: valid_recorded_at(60)})

      start_date = Date.utc_today() |> Date.add(-10)
      end_date = Date.utc_today()

      assert {:ok, data} = Dashboards.get_dashboard_data(scope, date_range: {start_date, end_date})

      sessions_stats = Enum.find(data.summary_stats, &(&1.metric_name == "sessions"))
      assert sessions_stats.stats.sum == 10.0
      assert sessions_stats.stats.count == 1
    end

    test "applies metric_type filter to time_series and summary_stats, excluding metrics of other types" do
      {user, scope} = user_with_scope()
      insert_integration!(user.id)
      insert_metric!(user.id, %{metric_name: "sessions", metric_type: "traffic", value: 10.0})
      insert_metric!(user.id, %{metric_name: "clicks", metric_type: "advertising", value: 999.0})

      assert {:ok, data} = Dashboards.get_dashboard_data(scope, metric_type: "traffic")

      metric_names = Enum.map(data.time_series, & &1.metric_name)
      assert "sessions" in metric_names
      refute "clicks" in metric_names
    end

    test "uses default_date_range/0 when no date_range option is provided" do
      {user, scope} = user_with_scope()
      insert_integration!(user.id)
      insert_metric!(user.id, %{metric_name: "sessions", value: 10.0, recorded_at: valid_recorded_at(5)})

      assert {:ok, data} = Dashboards.get_dashboard_data(scope, [])

      {_start, _end} = Dashboards.default_date_range()
      sessions_ts = Enum.find(data.time_series, &(&1.metric_name == "sessions"))
      assert sessions_ts != nil
      assert sessions_ts.data != []
    end

    test "returns empty time_series and empty summary_stats when the user has no metrics" do
      {user, scope} = user_with_scope()
      insert_integration!(user.id)

      assert {:ok, data} = Dashboards.get_dashboard_data(scope, [])

      assert data.time_series == []
      assert data.summary_stats == []
    end

    test "applied_filters in the result reflects all opts used including the resolved date_range" do
      {user, scope} = user_with_scope()
      insert_integration!(user.id)

      start_date = Date.utc_today() |> Date.add(-7)
      end_date = Date.utc_today()
      opts = [platform: :google_analytics, date_range: {start_date, end_date}]

      assert {:ok, %{applied_filters: applied}} = Dashboards.get_dashboard_data(scope, opts)

      assert Keyword.get(applied, :platform) == :google_analytics
      assert Keyword.get(applied, :date_range) == {start_date, end_date}
    end

    test "does not return data belonging to other users" do
      {user, scope} = user_with_scope()
      {other_user, _other_scope} = user_with_scope()

      insert_integration!(user.id)
      insert_metric!(user.id, %{metric_name: "sessions", value: 10.0})
      insert_metric!(other_user.id, %{metric_name: "revenue", value: 9999.0})

      assert {:ok, data} = Dashboards.get_dashboard_data(scope, [])

      metric_names = Enum.map(data.time_series, & &1.metric_name)
      assert "sessions" in metric_names
      refute "revenue" in metric_names
    end
  end

  # ---------------------------------------------------------------------------
  # build_chart_spec/2
  # ---------------------------------------------------------------------------

  describe "build_chart_spec/2" do
    # credo:disable-for-next-line Credo.Check.Readability.StringSigils
    test "returns a map with a \"$schema\" key pointing to a Vega-Lite schema URL" do
      data = [%{date: ~D[2025-01-01], value: 100.0}]
      spec = Dashboards.build_chart_spec("Sessions", data)

      assert is_map(spec)
      assert Map.has_key?(spec, "$schema")
      assert spec["$schema"] =~ "vega-lite"
    end

    # credo:disable-for-next-line Credo.Check.Readability.StringSigils
    test "returned map includes a \"mark\" key configured for a line chart with type \"line\"" do
      data = [%{date: ~D[2025-01-01], value: 50.0}]
      spec = Dashboards.build_chart_spec("Clicks", data)

      assert is_map(spec["mark"])
      assert spec["mark"]["type"] == "line"
    end

    # credo:disable-for-next-line Credo.Check.Readability.StringSigils
    test "returned map includes an \"encoding\" key with \"x\" mapped to the \"date\" field and \"y\" mapped to the \"value\" field" do
      data = [%{date: ~D[2025-01-01], value: 50.0}]
      spec = Dashboards.build_chart_spec("Revenue", data)

      assert is_map(spec["encoding"])
      assert spec["encoding"]["x"]["field"] == "date"
      assert spec["encoding"]["y"]["field"] == "value"
    end

    test "title in the returned spec matches the metric_name argument" do
      data = [%{date: ~D[2025-01-01], value: 50.0}]
      spec = Dashboards.build_chart_spec("Monthly Revenue", data)

      assert spec["title"] == "Monthly Revenue"
    end

    test "returns a valid Vega-Lite spec for an empty data list" do
      spec = Dashboards.build_chart_spec("Empty Metric", [])

      assert is_map(spec)
      assert Map.has_key?(spec, "$schema")
      assert spec["data"]["values"] == []
    end

    test "data points in the spec have dates serialized as ISO 8601 strings" do
      data = [
        %{date: ~D[2025-03-15], value: 42.0},
        %{date: ~D[2025-03-16], value: 58.5}
      ]

      spec = Dashboards.build_chart_spec("Pageviews", data)
      values = spec["data"]["values"]

      assert Enum.any?(values, fn v -> v["date"] == "2025-03-15" && v["value"] == 42.0 end)
      assert Enum.any?(values, fn v -> v["date"] == "2025-03-16" && v["value"] == 58.5 end)
    end
  end

  # ---------------------------------------------------------------------------
  # default_date_range/0
  # ---------------------------------------------------------------------------

  describe "default_date_range/0" do
    test "returns a two-element tuple of Date structs" do
      result = Dashboards.default_date_range()

      assert {start_date, end_date} = result
      assert %Date{} = start_date
      assert %Date{} = end_date
    end

    test "end_date is always yesterday relative to the current UTC date" do
      {_start_date, end_date} = Dashboards.default_date_range()
      yesterday = Date.utc_today() |> Date.add(-1)

      assert end_date == yesterday
    end

    test "start_date is always 30 days before the end_date" do
      {start_date, end_date} = Dashboards.default_date_range()

      assert Date.diff(end_date, start_date) == 30
    end

    test "start_date is always before end_date" do
      {start_date, end_date} = Dashboards.default_date_range()

      assert Date.compare(start_date, end_date) == :lt
    end
  end

  # ---------------------------------------------------------------------------
  # available_date_ranges/0
  # ---------------------------------------------------------------------------

  describe "available_date_ranges/0" do
    test "returns a list with exactly 5 entries" do
      result = Dashboards.available_date_ranges()

      assert length(result) == 5
    end

    test "list contains entries with keys: :last_7_days, :last_30_days, :last_90_days, :all_time, :custom" do
      result = Dashboards.available_date_ranges()
      keys = Enum.map(result, & &1.key)

      assert :last_7_days in keys
      assert :last_30_days in keys
      assert :last_90_days in keys
      assert :all_time in keys
      assert :custom in keys
    end

    test ":last_7_days range spans 7 days (diff of 6) ending on yesterday" do
      result = Dashboards.available_date_ranges()
      entry = Enum.find(result, &(&1.key == :last_7_days))
      {start_date, end_date} = entry.range

      yesterday = Date.utc_today() |> Date.add(-1)

      assert end_date == yesterday
      assert Date.diff(end_date, start_date) == 6
    end

    test ":last_30_days range spans 30 days (diff of 29) ending on yesterday" do
      result = Dashboards.available_date_ranges()
      entry = Enum.find(result, &(&1.key == :last_30_days))
      {start_date, end_date} = entry.range

      yesterday = Date.utc_today() |> Date.add(-1)

      assert end_date == yesterday
      assert Date.diff(end_date, start_date) == 29
    end

    test ":last_90_days range spans 90 days (diff of 89) ending on yesterday" do
      result = Dashboards.available_date_ranges()
      entry = Enum.find(result, &(&1.key == :last_90_days))
      {start_date, end_date} = entry.range

      yesterday = Date.utc_today() |> Date.add(-1)

      assert end_date == yesterday
      assert Date.diff(end_date, start_date) == 89
    end

    test ":all_time range is nil" do
      result = Dashboards.available_date_ranges()
      entry = Enum.find(result, &(&1.key == :all_time))

      assert entry.range == nil
    end

    test ":custom range is nil" do
      result = Dashboards.available_date_ranges()
      entry = Enum.find(result, &(&1.key == :custom))

      assert entry.range == nil
    end

    test "all bounded range end dates are yesterday, never today" do
      result = Dashboards.available_date_ranges()
      yesterday = Date.utc_today() |> Date.add(-1)

      bounded_entries = Enum.filter(result, fn entry -> entry.range != nil end)

      assert Enum.all?(bounded_entries, fn entry ->
               {_start, end_date} = entry.range
               end_date == yesterday
             end)
    end

    test "each entry has a non-empty label string" do
      result = Dashboards.available_date_ranges()

      assert Enum.all?(result, fn entry ->
               is_binary(entry.label) and byte_size(entry.label) > 0
             end)
    end
  end

  # ---------------------------------------------------------------------------
  # has_integrations?/1
  # ---------------------------------------------------------------------------

  describe "has_integrations?/1" do
    test "returns true when the user has one or more integrations" do
      {user, scope} = user_with_scope()
      insert_integration!(user.id)

      assert Dashboards.has_integrations?(scope) == true
    end

    test "returns false when the user has no integrations" do
      {_user, scope} = user_with_scope()

      assert Dashboards.has_integrations?(scope) == false
    end

    test "does not count integrations belonging to other users" do
      {user, scope} = user_with_scope()
      {other_user, _other_scope} = user_with_scope()

      insert_integration!(other_user.id)

      assert Dashboards.has_integrations?(scope) == false

      insert_integration!(user.id, :google)
      assert Dashboards.has_integrations?(scope) == true
    end
  end
end
