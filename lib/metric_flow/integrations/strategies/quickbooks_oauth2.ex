defmodule MetricFlow.Integrations.Strategies.QuickBooksOAuth2 do
  @moduledoc """
  Custom Assent OAuth2 strategy for QuickBooks that skips the userinfo fetch.

  QuickBooks Online uses OAuth 2.0 for token exchange but does not require
  (or reliably support) the OpenID Connect userinfo endpoint for the
  `com.intuit.quickbooks.accounting` scope. The `realmId` (company ID)
  is returned as a query parameter on the callback URL, not from userinfo.

  This strategy overrides `fetch_user/2` to return an empty map, allowing
  the token exchange to complete without a userinfo HTTP call.
  """

  use Assent.Strategy.OAuth2.Base

  @impl true
  def default_config(_config), do: []

  @impl true
  def normalize(_config, user), do: {:ok, user}

  @impl true
  def fetch_user(_config, _token) do
    {:ok, %{}}
  end
end
