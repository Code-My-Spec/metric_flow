defmodule MetricFlowTest.IntegrationsFixtures do
  @moduledoc """
  Test helpers for creating integration entities.

  Google products (`:google_analytics`, `:google_ads`,
  `:google_search_console`, `:google_business`) live on the account's single
  `:google` integration. Asking for one of them creates that `:google`
  integration — or adds to the account's existing one — granting the
  product's scope and merging its provider_metadata (selection) in.
  """

  alias MetricFlow.Integrations
  alias MetricFlow.Integrations.Integration
  alias MetricFlow.Repo

  @doc """
  Inserts an integration connected by `user`, owned by `attrs[:account_id]`
  or else the user's default account. Defaults to Google with Analytics
  granted and a property selected.
  """
  def integration_fixture(user, attrs \\ %{}) do
    defaults = %{
      user_id: user.id,
      account_id: MetricFlowTest.UsersFixtures.default_account_id(user),
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

    put_integration!(Map.merge(defaults, Map.new(attrs)))
  end

  @doc """
  Inserts `attrs` as an integration. A Google product becomes (or is merged
  into) the account's `:google` integration with that product's scope
  granted; tokens and expiry are taken from `attrs`.
  """
  def put_integration!(attrs) do
    attrs = Map.new(attrs)
    product = attrs[:provider]

    if Integrations.google_product?(product) do
      scopes = Map.fetch!(Integrations.google_product_scopes(), product)

      attrs =
        attrs
        |> Map.put(:provider, :google)
        |> Map.update(:granted_scopes, scopes, &Enum.uniq((&1 || []) ++ scopes))

      case Repo.get_by(Integration, account_id: attrs[:account_id], provider: :google) do
        nil ->
          insert!(attrs)

        existing ->
          existing
          |> Integration.changeset(
            attrs
            |> Map.drop([:user_id, :account_id, :provider])
            |> Map.put(
              :granted_scopes,
              Enum.uniq(existing.granted_scopes ++ attrs.granted_scopes)
            )
            |> Map.put(
              :provider_metadata,
              Map.merge(existing.provider_metadata || %{}, attrs[:provider_metadata] || %{})
            )
          )
          |> Repo.update!()
      end
    else
      insert!(attrs)
    end
  end

  defp insert!(attrs) do
    %Integration{}
    |> Integration.changeset(attrs)
    |> Repo.insert!()
  end
end
