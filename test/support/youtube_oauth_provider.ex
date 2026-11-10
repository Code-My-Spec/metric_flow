defmodule MetricFlowTest.YouTubeOAuthProvider do
  @moduledoc """
  Synthetic external Google responses for YouTube acceptance scenarios.
  Uses the real Assent OAuth2 exchange; does not create integration records
  or replace the application's controller, LiveView, or selection logic.
  Consent-scope specifications use the application provider, not this fixture.
  """

  def config do
    [
      client_id: "synthetic-youtube-client",
      client_secret: "synthetic-youtube-secret",
      redirect_uri: MetricFlowWeb.Endpoint.url() <> "/app/integrations/oauth/callback/youtube",
      base_url: "https://accounts.google.com",
      authorize_url: "https://accounts.google.com/o/oauth2/v2/auth",
      token_url: "https://oauth2.googleapis.com/token",
      user_url: "https://www.googleapis.com/oauth2/v3/userinfo",
      authorization_params: [scope: scopes(), access_type: "offline"],
      http_adapter: {Assent.HTTPAdapter.Req, [plug: &__MODULE__.respond/1]}
    ]
  end

  def strategy, do: Assent.Strategy.OAuth2
  defdelegate normalize_user(user), to: MetricFlow.Integrations.Providers.Google

  def respond(%Plug.Conn{method: "POST", request_path: "/token"} = conn) do
    json(conn, %{
      "access_token" => "synthetic-youtube-access",
      "refresh_token" => "synthetic-youtube-refresh",
      "expires_in" => 3600,
      "token_type" => "Bearer",
      "scope" => scopes()
    })
  end

  def respond(%Plug.Conn{method: "GET", request_path: "/oauth2/v3/userinfo"} = conn) do
    json(conn, %{
      "sub" => "synthetic-dana-youtube",
      "email" => "dana@example.com",
      "name" => "Dana",
      "email_verified" => true
    })
  end

  def respond(%Plug.Conn{method: "GET", request_path: "/youtube/v3/channels"} = conn) do
    json(conn, %{
      "kind" => "youtube#channelListResponse",
      "pageInfo" => %{"totalResults" => 2, "resultsPerPage" => 2},
      "items" => [
        %{"id" => "UC_dana_personal", "snippet" => %{"title" => "Dana Personal"}},
        %{"id" => "UC_dana_brand", "snippet" => %{"title" => "Dana Brand"}}
      ]
    })
  end

  def respond(conn),
    do: raise("Unexpected YouTube fixture request: #{conn.method} #{conn.request_path}")

  defp scopes do
    Enum.join(
      [
        "email",
        "profile",
        "https://www.googleapis.com/auth/youtube.readonly",
        "https://www.googleapis.com/auth/yt-analytics.readonly",
        "https://www.googleapis.com/auth/yt-analytics-monetary.readonly"
      ],
      " "
    )
  end

  defp json(conn, body) do
    conn
    |> Plug.Conn.put_resp_content_type("application/json")
    |> Plug.Conn.send_resp(200, Jason.encode!(body))
  end
end
