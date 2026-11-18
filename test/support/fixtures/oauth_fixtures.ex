defmodule MetricFlowTest.OauthFixtures do
  @moduledoc "OAuth clients and access tokens for the MCP authorization server."

  alias MetricFlow.Oauth

  def oauth_application_fixture(attrs \\ %{}) do
    {:ok, app} =
      attrs
      |> Enum.into(%{
        name: "Test Agent",
        uid: "mcp_test_#{System.unique_integer([:positive])}",
        secret: "secret-#{System.unique_integer([:positive])}",
        redirect_uri: "https://agent.example.com/callback",
        scopes: "read write"
      })
      |> Oauth.register_application()

    app
  end

  @doc "An access token for `user`, issued to `app` (a new client by default)."
  def oauth_token_fixture(user, app \\ nil) do
    app = app || oauth_application_fixture()

    {:ok, token} =
      ExOauth2Provider.AccessTokens.create_token(
        user,
        %{application: app, use_refresh_token: true},
        otp_app: :metric_flow
      )

    token
  end

  @doc "A PKCE verifier and its S256 challenge."
  def pkce_pair do
    verifier = :crypto.strong_rand_bytes(32) |> Base.url_encode64(padding: false)
    challenge = :crypto.hash(:sha256, verifier) |> Base.url_encode64(padding: false)
    {verifier, challenge}
  end
end
