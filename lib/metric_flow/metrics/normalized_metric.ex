defmodule MetricFlow.Metrics.NormalizedMetric do
  @moduledoc """
  Canonical cross-provider metric vocabulary.

  Maps provider-specific metric names to normalized names that enable
  aggregation across providers. For example, GA4's `activeUsers`, Facebook's
  `reach`, and Search Console's `impressions` all map to their canonical
  equivalents so you can query "total clicks" regardless of source.

  Ported from the anderson-reports-fetcher `normalized-metric-map.js`.

  ## Vocabulary

  `impressions`, `clicks`, `conversions`, `engagement`, `users`, `new_users`,
  `sessions`, `duration`, `views`, `total_cost`, `cost_rate`, `orders`,
  `position`, `rate`, `conversions_value`, `bounce_rate`, `reviews`
  """

  @type normalized_name :: String.t()

  # ---------------------------------------------------------------------------
  # Per-provider mappings
  # ---------------------------------------------------------------------------

  @google_analytics %{
    "activeUsers" => "users",
    "newUsers" => "new_users",
    "sessions" => "sessions",
    "screenPageViews" => "views",
    "averageSessionDuration" => "duration",
    "bounceRate" => "bounce_rate"
  }

  @google_ads %{
    "impressions" => "impressions",
    "clicks" => "clicks",
    "cost" => "total_cost",
    "conversions" => "conversions",
    "ctr" => "rate",
    "average_cpc" => "cost_rate",
    "conversions_value" => "conversions_value"
  }

  @facebook_ads %{
    "impressions" => "impressions",
    "clicks" => "clicks",
    "spend" => "total_cost",
    "cpm" => "cost_rate",
    "cpc" => "cost_rate",
    "ctr" => "rate",
    "conversions" => "conversions",
    "conversion_rate" => "rate"
  }

  @google_search_console %{
    "clicks" => "clicks",
    "impressions" => "impressions",
    "ctr" => "rate",
    "position" => "position"
  }

  @quickbooks %{
    "QUICKBOOKS_ACCOUNT_DAILY_CREDITS" => "revenue",
    "QUICKBOOKS_ACCOUNT_DAILY_DEBITS" => "expenses"
  }

  @google_business %{
    "impressions_desktop_maps" => "impressions",
    "impressions_desktop_search" => "impressions",
    "impressions_mobile_maps" => "impressions",
    "call_clicks" => "clicks",
    "website_clicks" => "clicks",
    "food_menu_clicks" => "clicks",
    "bookings" => "conversions",
    "food_orders" => "orders",
    "review_rating" => "reviews",
    "review_count" => "reviews"
  }

  @provider_maps %{
    google_analytics: @google_analytics,
    google_ads: @google_ads,
    facebook_ads: @facebook_ads,
    google_search_console: @google_search_console,
    quickbooks: @quickbooks,
    google_business: @google_business,
    google_business_reviews: @google_business
  }

  @doc """
  Returns the normalized metric name for a given provider and raw metric name.

  Falls back to downcasing the metric_name if no mapping exists.

  ## Examples

      iex> NormalizedMetric.normalize(:google_analytics, "activeUsers")
      "users"

      iex> NormalizedMetric.normalize(:google_ads, "clicks")
      "clicks"

      iex> NormalizedMetric.normalize(:quickbooks, "QUICKBOOKS_ACCOUNT_DAILY_CREDITS")
      "revenue"
  """
  @spec normalize(atom(), String.t()) :: normalized_name()
  def normalize(provider, metric_name) when is_atom(provider) and is_binary(metric_name) do
    case Map.get(@provider_maps, provider) do
      nil -> String.downcase(metric_name)
      mapping -> Map.get(mapping, metric_name, String.downcase(metric_name))
    end
  end

  @doc """
  Returns the full provider mapping for inspection/debugging.
  """
  @spec mapping_for(atom()) :: map()
  def mapping_for(provider), do: Map.get(@provider_maps, provider, %{})
end
