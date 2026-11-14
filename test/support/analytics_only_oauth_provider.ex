defmodule MetricFlowTest.AnalyticsOnlyOAuthProvider do
  @moduledoc """
  External HTTP fixture for an Analytics connection without YouTube consent.
  The real OAuth controller, strategy, and persistence flow remain in use.
  Responses are synthetic test data, not recorded Google traffic.
  """

  alias MetricFlow.Integrations.Providers.GoogleAnalytics

  def config do
    GoogleAnalytics.config()
    |> Keyword.merge(
      base_url: "https://accounts.google.com",
      authorize_url: "https://accounts.google.com/o/oauth2/v2/auth",
      token_url: "https://oauth2.googleapis.com/token",
      user_url: "https://www.googleapis.com/oauth2/v3/userinfo",
      http_adapter: {Assent.HTTPAdapter.Req, [plug: &__MODULE__.respond/1]}
    )
  end

  def strategy, do: Assent.Strategy.OAuth2
  defdelegate normalize_user(user), to: GoogleAnalytics

  def respond(%Plug.Conn{method: "POST", request_path: "/token"} = conn) do
    json(conn, %{
      "access_token" => "synthetic-analytics-only-access",
      "refresh_token" => "synthetic-analytics-only-refresh",
      "expires_in" => 3600,
      "token_type" => "Bearer",
      "scope" => "email profile https://www.googleapis.com/auth/analytics.readonly"
    })
  end

  def respond(%Plug.Conn{method: "GET", request_path: "/oauth2/v3/userinfo"} = conn) do
    json(conn, %{
      "sub" => "synthetic-dana-google-id",
      "email" => "dana@example.com",
      "name" => "Dana",
      "email_verified" => true
    })
  end

  def respond(conn) do
    raise "Unexpected OAuth fixture request: #{conn.method} #{conn.request_path}"
  end

  defp json(conn, body) do
    conn
    |> Plug.Conn.put_resp_content_type("application/json")
    |> Plug.Conn.send_resp(200, Jason.encode!(body))
  end
end
