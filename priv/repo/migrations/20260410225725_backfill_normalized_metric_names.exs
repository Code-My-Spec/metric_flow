defmodule MetricFlow.Repo.Migrations.BackfillNormalizedMetricNames do
  use Ecto.Migration

  # Per-provider metric_name → normalized_metric_name mappings.
  # Matches MetricFlow.Metrics.NormalizedMetric at time of migration.
  @mappings %{
    "google_analytics" => %{
      "activeUsers" => "users",
      "newUsers" => "new_users",
      "sessions" => "sessions",
      "screenPageViews" => "views",
      "averageSessionDuration" => "duration",
      "bounceRate" => "bounce_rate"
    },
    "google_ads" => %{
      "impressions" => "impressions",
      "clicks" => "clicks",
      "cost" => "total_cost",
      "conversions" => "conversions",
      "ctr" => "rate",
      "average_cpc" => "cost_rate",
      "conversions_value" => "conversions_value"
    },
    "facebook_ads" => %{
      "impressions" => "impressions",
      "clicks" => "clicks",
      "spend" => "total_cost",
      "cpm" => "cost_rate",
      "cpc" => "cost_rate",
      "ctr" => "rate",
      "conversions" => "conversions",
      "conversion_rate" => "rate"
    },
    "google_search_console" => %{
      "clicks" => "clicks",
      "impressions" => "impressions",
      "ctr" => "rate",
      "position" => "position"
    },
    "quickbooks" => %{
      "QUICKBOOKS_ACCOUNT_DAILY_CREDITS" => "revenue",
      "QUICKBOOKS_ACCOUNT_DAILY_DEBITS" => "expenses"
    },
    "google_business" => %{
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
    },
    "google_business_reviews" => %{
      "review_rating" => "reviews",
      "review_count" => "reviews"
    }
  }

  def up do
    # Update each provider's metrics using CASE statements for efficiency
    for {provider, mapping} <- @mappings do
      when_clauses =
        Enum.map_join(mapping, " ", fn {raw, normalized} ->
          "WHEN metric_name = '#{raw}' THEN '#{normalized}'"
        end)

      execute("""
      UPDATE metrics
      SET normalized_metric_name = CASE #{when_clauses} ELSE LOWER(metric_name) END
      WHERE provider = '#{provider}'
        AND normalized_metric_name IS NULL
      """)
    end

    # Catch any remaining rows from providers not in the mapping
    execute("""
    UPDATE metrics
    SET normalized_metric_name = LOWER(metric_name)
    WHERE normalized_metric_name IS NULL
    """)
  end

  def down do
    execute("UPDATE metrics SET normalized_metric_name = NULL")
  end
end
