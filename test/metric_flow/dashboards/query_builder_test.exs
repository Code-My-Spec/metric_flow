defmodule MetricFlow.Dashboards.QueryBuilderTest do
  use ExUnit.Case, async: true

  alias MetricFlow.Dashboards.QueryBuilder

  # ---------------------------------------------------------------------------
  # build/1
  # ---------------------------------------------------------------------------

  describe "build/1" do
    test "returns a query_params map with nil date_range by default" do
      params = QueryBuilder.build()

      assert params.date_range == nil
    end

    test "returns a query_params map with nil provider by default" do
      params = QueryBuilder.build()

      assert params.provider == nil
    end

    test "returns a query_params map with empty metric_names by default" do
      params = QueryBuilder.build()

      assert params.metric_names == []
    end

    test "sets date_range from :date_range option" do
      range = {~D[2025-01-01], ~D[2025-01-31]}
      params = QueryBuilder.build(date_range: range)

      assert params.date_range == range
    end

    test "sets provider from :platform atom option" do
      params = QueryBuilder.build(platform: :quickbooks)

      assert params.provider == :quickbooks
    end

    test "expands :google platform into [:google_analytics, :google_ads]" do
      params = QueryBuilder.build(platform: :google)

      assert params.provider == [:google_analytics, :google_ads]
    end

    test "sets provider from a list of platform atoms" do
      params = QueryBuilder.build(platform: [:facebook_ads, :quickbooks])

      assert params.provider == [:facebook_ads, :quickbooks]
    end

    test "sets nil provider when :platform is nil" do
      params = QueryBuilder.build(platform: nil)

      assert params.provider == nil
    end

    test "sets nil provider when :platform is an empty list" do
      params = QueryBuilder.build(platform: [])

      assert params.provider == nil
    end

    test "sets metric_names from :metric_names option" do
      params = QueryBuilder.build(metric_names: ["Impressions", "Clicks"])

      assert params.metric_names == ["Impressions", "Clicks"]
    end

    test "accepts all options together" do
      range = {~D[2025-01-01], ~D[2025-03-31]}

      params =
        QueryBuilder.build(
          date_range: range,
          platform: :facebook_ads,
          metric_names: ["Spend"]
        )

      assert params.date_range == range
      assert params.provider == :facebook_ads
      assert params.metric_names == ["Spend"]
    end
  end

  # ---------------------------------------------------------------------------
  # to_keyword/1
  # ---------------------------------------------------------------------------

  describe "to_keyword/1" do
    test "omits :date_range key when date_range is nil" do
      params = %{date_range: nil, provider: nil, metric_names: []}

      result = QueryBuilder.to_keyword(params)

      refute Keyword.has_key?(result, :date_range)
    end

    test "includes :date_range key when date_range is set" do
      range = {~D[2025-01-01], ~D[2025-01-31]}
      params = %{date_range: range, provider: nil, metric_names: []}

      result = QueryBuilder.to_keyword(params)

      assert Keyword.get(result, :date_range) == range
    end

    test "omits :provider key when provider is nil" do
      params = %{date_range: nil, provider: nil, metric_names: []}

      result = QueryBuilder.to_keyword(params)

      refute Keyword.has_key?(result, :provider)
    end

    test "includes :provider key when provider is an atom" do
      params = %{date_range: nil, provider: :quickbooks, metric_names: []}

      result = QueryBuilder.to_keyword(params)

      assert Keyword.get(result, :provider) == :quickbooks
    end

    test "includes :provider key when provider is a list of atoms" do
      params = %{date_range: nil, provider: [:google_analytics, :google_ads], metric_names: []}

      result = QueryBuilder.to_keyword(params)

      assert Keyword.get(result, :provider) == [:google_analytics, :google_ads]
    end

    test "omits :metric_names key when metric_names is empty" do
      params = %{date_range: nil, provider: nil, metric_names: []}

      result = QueryBuilder.to_keyword(params)

      refute Keyword.has_key?(result, :metric_names)
    end

    test "includes :metric_names key when metric_names is non-empty" do
      params = %{date_range: nil, provider: nil, metric_names: ["Impressions"]}

      result = QueryBuilder.to_keyword(params)

      assert Keyword.get(result, :metric_names) == ["Impressions"]
    end

    test "returns an empty keyword list when all fields are nil or empty" do
      params = %{date_range: nil, provider: nil, metric_names: []}

      assert QueryBuilder.to_keyword(params) == []
    end
  end

  # ---------------------------------------------------------------------------
  # has_date_range?/1
  # ---------------------------------------------------------------------------

  describe "has_date_range?/1" do
    test "returns true when date_range is a {Date, Date} tuple" do
      params = %{date_range: {~D[2025-01-01], ~D[2025-01-31]}, provider: nil, metric_names: []}

      assert QueryBuilder.has_date_range?(params) == true
    end

    test "returns false when date_range is nil" do
      params = %{date_range: nil, provider: nil, metric_names: []}

      assert QueryBuilder.has_date_range?(params) == false
    end
  end

  # ---------------------------------------------------------------------------
  # has_platform_filter?/1
  # ---------------------------------------------------------------------------

  describe "has_platform_filter?/1" do
    test "returns false when provider is nil" do
      params = %{date_range: nil, provider: nil, metric_names: []}

      assert QueryBuilder.has_platform_filter?(params) == false
    end

    test "returns false when provider is an empty list" do
      params = %{date_range: nil, provider: [], metric_names: []}

      assert QueryBuilder.has_platform_filter?(params) == false
    end

    test "returns true when provider is an atom" do
      params = %{date_range: nil, provider: :quickbooks, metric_names: []}

      assert QueryBuilder.has_platform_filter?(params) == true
    end

    test "returns true when provider is a list of atoms" do
      params = %{date_range: nil, provider: [:google_analytics, :google_ads], metric_names: []}

      assert QueryBuilder.has_platform_filter?(params) == true
    end
  end

  # ---------------------------------------------------------------------------
  # has_metric_name_filter?/1
  # ---------------------------------------------------------------------------

  describe "has_metric_name_filter?/1" do
    test "returns false when metric_names is empty" do
      params = %{date_range: nil, provider: nil, metric_names: []}

      assert QueryBuilder.has_metric_name_filter?(params) == false
    end

    test "returns true when metric_names is non-empty" do
      params = %{date_range: nil, provider: nil, metric_names: ["Impressions"]}

      assert QueryBuilder.has_metric_name_filter?(params) == true
    end
  end

  # ---------------------------------------------------------------------------
  # merge/2
  # ---------------------------------------------------------------------------

  describe "merge/2" do
    test "updates date_range from opts" do
      original = QueryBuilder.build()
      range = {~D[2025-06-01], ~D[2025-06-30]}

      result = QueryBuilder.merge(original, date_range: range)

      assert result.date_range == range
    end

    test "updates provider from :platform opt" do
      original = QueryBuilder.build()

      result = QueryBuilder.merge(original, platform: :facebook_ads)

      assert result.provider == :facebook_ads
    end

    test "expands :google platform during merge" do
      original = QueryBuilder.build()

      result = QueryBuilder.merge(original, platform: :google)

      assert result.provider == [:google_analytics, :google_ads]
    end

    test "updates metric_names from opts" do
      original = QueryBuilder.build(metric_names: ["Impressions"])

      result = QueryBuilder.merge(original, metric_names: ["Clicks", "Spend"])

      assert result.metric_names == ["Clicks", "Spend"]
    end

    test "ignores unknown option keys" do
      original = QueryBuilder.build(platform: :quickbooks)

      result = QueryBuilder.merge(original, unknown_key: "value")

      assert result.provider == :quickbooks
    end

    test "preserves unchanged fields" do
      range = {~D[2025-01-01], ~D[2025-01-31]}
      original = QueryBuilder.build(date_range: range, platform: :quickbooks)

      result = QueryBuilder.merge(original, metric_names: ["Revenue"])

      assert result.date_range == range
      assert result.provider == :quickbooks
      assert result.metric_names == ["Revenue"]
    end
  end
end
