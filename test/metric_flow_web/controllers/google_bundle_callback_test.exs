defmodule MetricFlowWeb.GoogleBundleCallbackTest do
  use MetricFlowTest.ConnCase, async: false

  import MetricFlowTest.UsersFixtures

  alias MetricFlow.Integrations
  alias MetricFlow.Integrations.OAuthStateStore

  # Google answering the single grant with every product scope ticked —
  # the exact scope list dev's failing callback carried.
  defmodule FullGoogle do
    alias MetricFlow.Integrations.Providers.GoogleAnalytics

    @scope "email profile openid https://www.googleapis.com/auth/webmasters.readonly " <>
             "https://www.googleapis.com/auth/business.manage " <>
             "https://www.googleapis.com/auth/analytics.readonly " <>
             "https://www.googleapis.com/auth/adwords " <>
             "https://www.googleapis.com/auth/yt-analytics-monetary.readonly " <>
             "https://www.googleapis.com/auth/youtube.readonly " <>
             "https://www.googleapis.com/auth/yt-analytics.readonly"

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

    def respond(%Plug.Conn{method: "POST"} = conn),
      do:
        json(conn, %{
          "access_token" => "a",
          "refresh_token" => "r",
          "expires_in" => 3600,
          "token_type" => "Bearer",
          "scope" => @scope
        })

    def respond(conn),
      do: json(conn, %{"sub" => "g-1", "email" => "joel@example.com", "email_verified" => true})

    defp json(conn, body) do
      conn
      |> Plug.Conn.put_resp_content_type("application/json")
      |> Plug.Conn.send_resp(200, Jason.encode!(body))
    end
  end

  setup %{conn: conn} do
    original = Application.get_env(:metric_flow, :oauth_providers)
    Application.put_env(:metric_flow, :oauth_providers, %{google_analytics: FullGoogle})

    on_exit(fn ->
      if original,
        do: Application.put_env(:metric_flow, :oauth_providers, original),
        else: Application.delete_env(:metric_flow, :oauth_providers)
    end)

    user = user_with_account_fixture()
    %{conn: log_in_user(conn, user), scope: account_scope_fixture(user)}
  end

  test "a full-scope bundle callback connects every Google product and redirects", %{
    conn: conn,
    scope: scope
  } do
    OAuthStateStore.store("st-1", %{
      state: "st-1",
      google_bundle: true,
      account_id: scope.account_id,
      return_to: "/app/onboarding/connect?step=google"
    })

    conn =
      get(conn, "/app/integrations/oauth/callback/google_analytics", %{
        "state" => "st-1",
        "code" => "c"
      })

    assert redirected_to(conn) == "/app/onboarding/connect?step=google"

    for p <- [:google_analytics, :google_ads, :google_search_console, :google_business, :youtube],
        do: assert(Integrations.connected?(scope, p), "#{p} not connected")
  end
end
