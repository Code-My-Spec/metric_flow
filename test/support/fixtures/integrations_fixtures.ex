defmodule MetricFlowTest.IntegrationsFixtures do
  @moduledoc """
  Test helpers for creating integration entities.
  """

  alias MetricFlow.Integrations.Integration
  alias MetricFlow.Repo

  def integration_fixture(user, attrs \\ %{}) do
    defaults = %{
      user_id: user.id,
      provider: :google_analytics,
      access_token: "test_access_token_#{System.unique_integer([:positive])}",
      refresh_token: "test_refresh_token",
      expires_at: DateTime.add(DateTime.utc_now(), 3600, :second),
      granted_scopes: ["https://www.googleapis.com/auth/analytics.readonly"],
      provider_metadata: %{
        "email" => user.email,
        "property_id" => "GA4-67890",
        "selected_accounts" => ["UA-12345 (Main Site)", "GA4-67890 (App)"]
      }
    }

    merged = Map.merge(defaults, Map.new(attrs))

    %Integration{}
    |> Integration.changeset(merged)
    |> Repo.insert!()
  end
end
