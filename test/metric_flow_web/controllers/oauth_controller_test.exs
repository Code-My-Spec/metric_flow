defmodule MetricFlowWeb.OAuthControllerTest do
  use MetricFlowTest.ConnCase, async: true

  import MetricFlowTest.UsersFixtures
  import MetricFlowTest.OauthFixtures

  @redirect "https://agent.example.com/callback"

  defp authorize_params(app, challenge, extra \\ %{}) do
    Map.merge(
      %{
        "client_id" => app.uid,
        "redirect_uri" => @redirect,
        "response_type" => "code",
        "state" => "xyz",
        "code_challenge" => challenge,
        "code_challenge_method" => "S256"
      },
      extra
    )
  end

  # Approve on the consent page; returns the authorization code.
  defp approve(conn, user, app, challenge) do
    conn =
      conn |> log_in_user(user) |> post(~p"/oauth/authorize", authorize_params(app, challenge))

    location = redirected_to(conn)
    assert location =~ @redirect
    query = URI.decode_query(URI.parse(location).query)
    assert query["state"] == "xyz"
    query["code"]
  end

  defp exchange(conn, app, code, verifier) do
    post(conn, ~p"/oauth/token", %{
      "grant_type" => "authorization_code",
      "client_id" => app.uid,
      "client_secret" => app.secret,
      "redirect_uri" => @redirect,
      "code" => code,
      "code_verifier" => verifier
    })
  end

  describe "GET /oauth/authorize" do
    test "bounces an anonymous user through login and back", %{conn: conn} do
      app = oauth_application_fixture()
      {_verifier, challenge} = pkce_pair()

      conn = get(conn, ~p"/oauth/authorize", authorize_params(app, challenge))

      assert redirected_to(conn) == ~p"/users/log-in"
      return_to = get_session(conn, :user_return_to)
      assert return_to =~ "/oauth/authorize?"
      assert return_to =~ "code_challenge=#{challenge}"
    end

    test "shows the consent page with the unverified-client warning", %{conn: conn} do
      app = oauth_application_fixture(%{name: "Claude"})
      {_verifier, challenge} = pkce_pair()

      html =
        conn
        |> log_in_user(user_fixture())
        |> get(~p"/oauth/authorize", authorize_params(app, challenge))
        |> html_response(200)

      assert html =~ "Claude"
      assert html =~ "wants to set up and check data sources for accounts you can access"
      assert html =~ "is not verified"
      assert html =~ ~s(name="code_challenge" value="#{challenge}")
    end

    test "rejects a request without a PKCE challenge", %{conn: conn} do
      app = oauth_application_fixture()

      for params <- [
            Map.drop(authorize_params(app, "x"), ["code_challenge"]),
            authorize_params(app, String.duplicate("a", 43), %{"code_challenge_method" => "plain"})
          ] do
        conn = conn |> log_in_user(user_fixture()) |> get(~p"/oauth/authorize", params)
        assert html_response(conn, 400) =~ "code_challenge"
      end
    end

    test "an unknown client gets an error, not a redirect", %{conn: conn} do
      {_verifier, challenge} = pkce_pair()

      conn =
        conn
        |> log_in_user(user_fixture())
        |> get(~p"/oauth/authorize", authorize_params(%{uid: "nope"}, challenge))

      assert conn.status in 400..499
      refute conn.status in 300..399
    end
  end

  describe "authorization code + PKCE" do
    setup do
      %{user: user_fixture(), app: oauth_application_fixture()}
    end

    test "approve, then exchange with the right verifier", %{conn: conn, user: user, app: app} do
      {verifier, challenge} = pkce_pair()
      code = approve(conn, user, app, challenge)

      body = conn |> exchange(app, code, verifier) |> json_response(200)

      assert %{"access_token" => access, "refresh_token" => refresh, "token_type" => "Bearer"} =
               body

      assert {:ok, user.id} == MetricFlow.Oauth.verify_access_token(access)
      assert is_binary(refresh)
    end

    test "a repeat authorization that skips consent still binds the challenge", %{
      conn: conn,
      user: user,
      app: app
    } do
      {verifier, challenge} = pkce_pair()
      code = approve(conn, user, app, challenge)
      conn |> exchange(app, code, verifier) |> json_response(200)

      # Already authorized: the library redirects with a fresh code at once.
      {verifier2, challenge2} = pkce_pair()

      location =
        conn
        |> log_in_user(user)
        |> get(~p"/oauth/authorize", authorize_params(app, challenge2))
        |> redirected_to()

      code2 = URI.decode_query(URI.parse(location).query)["code"]

      assert %{"error" => "invalid_grant"} =
               conn |> exchange(app, code2, verifier) |> json_response(400)

      assert %{"access_token" => _} =
               conn |> exchange(app, code2, verifier2) |> json_response(200)
    end

    test "a wrong verifier is refused", %{conn: conn, user: user, app: app} do
      {_verifier, challenge} = pkce_pair()
      {other_verifier, _} = pkce_pair()
      code = approve(conn, user, app, challenge)

      assert %{"error" => "invalid_grant"} =
               conn |> exchange(app, code, other_verifier) |> json_response(400)
    end

    test "a missing verifier is refused", %{conn: conn, user: user, app: app} do
      {_verifier, challenge} = pkce_pair()
      code = approve(conn, user, app, challenge)

      assert %{"error" => "invalid_grant"} =
               conn |> exchange(app, code, nil) |> json_response(400)
    end

    test "approving without a challenge issues no code", %{conn: conn, user: user, app: app} do
      params = Map.drop(authorize_params(app, "x"), ["code_challenge", "code_challenge_method"])
      conn = conn |> log_in_user(user) |> post(~p"/oauth/authorize", params)
      assert conn.status == 400
    end

    test "client_secret_basic is accepted at the token endpoint", %{
      conn: conn,
      user: user,
      app: app
    } do
      {verifier, challenge} = pkce_pair()
      code = approve(conn, user, app, challenge)

      body =
        conn
        |> put_req_header("authorization", "Basic " <> Base.encode64("#{app.uid}:#{app.secret}"))
        |> post(~p"/oauth/token", %{
          "grant_type" => "authorization_code",
          "redirect_uri" => @redirect,
          "code" => code,
          "code_verifier" => verifier
        })
        |> json_response(200)

      assert is_binary(body["access_token"])
    end

    test "refresh issues a new token; a revoked one cannot be refreshed", %{
      conn: conn,
      user: user,
      app: app
    } do
      {verifier, challenge} = pkce_pair()
      code = approve(conn, user, app, challenge)
      tokens = conn |> exchange(app, code, verifier) |> json_response(200)

      refresh = fn token ->
        post(conn, ~p"/oauth/token", %{
          "grant_type" => "refresh_token",
          "client_id" => app.uid,
          "client_secret" => app.secret,
          "refresh_token" => token
        })
      end

      renewed = tokens["refresh_token"] |> refresh.() |> json_response(200)
      assert renewed["access_token"] != tokens["access_token"]

      revoked =
        post(conn, ~p"/oauth/revoke", %{
          "token" => renewed["access_token"],
          "client_id" => app.uid,
          "client_secret" => app.secret
        })

      assert json_response(revoked, 200) == %{}
      assert {:error, :invalid} = MetricFlow.Oauth.verify_access_token(renewed["access_token"])

      assert %{"error" => "invalid_grant"} =
               renewed["refresh_token"] |> refresh.() |> json_response(400)
    end

    test "the client-credentials grant is not offered", %{conn: conn, app: app} do
      conn =
        post(conn, ~p"/oauth/token", %{
          "grant_type" => "client_credentials",
          "client_id" => app.uid,
          "client_secret" => app.secret
        })

      assert %{"error" => "unsupported_grant_type"} = json_response(conn, 422)
    end
  end

  describe "POST /oauth/register" do
    test "registers a client with a secret (RFC 7591)", %{conn: conn} do
      body =
        conn
        |> post(~p"/oauth/register", %{
          "client_name" => "ChatGPT",
          "redirect_uris" => ["https://chatgpt.com/connector/oauth/test"]
        })
        |> json_response(201)

      assert "mcp_" <> _ = body["client_id"]
      assert is_binary(body["client_secret"])
      assert body["token_endpoint_auth_method"] == "client_secret_basic"
      assert body["redirect_uris"] == ["https://chatgpt.com/connector/oauth/test"]
    end

    test "the root /register fallback works too", %{conn: conn} do
      assert conn
             |> post("/register", %{"redirect_uris" => ["http://localhost:3000/cb"]})
             |> json_response(201)
    end

    test "rejects insecure or missing redirect URIs", %{conn: conn} do
      assert %{"error" => "invalid_redirect_uri"} =
               conn
               |> post(~p"/oauth/register", %{"redirect_uris" => ["http://evil.example/cb"]})
               |> json_response(400)

      assert %{"error" => "invalid_redirect_uri"} =
               conn |> post(~p"/oauth/register", %{}) |> json_response(400)
    end
  end

  describe "discovery" do
    test "authorization server metadata advertises S256 and the endpoints", %{conn: conn} do
      base = MetricFlowWeb.Endpoint.url()

      for path <- [
            "/.well-known/oauth-authorization-server",
            "/.well-known/oauth-authorization-server/mcp"
          ] do
        body = conn |> get(path) |> json_response(200)
        assert body["issuer"] == base
        assert body["authorization_endpoint"] == base <> "/oauth/authorize"
        assert body["token_endpoint"] == base <> "/oauth/token"
        assert body["registration_endpoint"] == base <> "/oauth/register"
        assert body["code_challenge_methods_supported"] == ["S256"]
        assert "client_secret_basic" in body["token_endpoint_auth_methods_supported"]
      end
    end

    test "protected resource metadata names the resource asked about", %{conn: conn} do
      base = MetricFlowWeb.Endpoint.url()

      bare = conn |> get("/.well-known/oauth-protected-resource") |> json_response(200)
      assert bare["resource"] == base <> "/mcp"
      assert bare["authorization_servers"] == [base]

      suffixed = conn |> get("/.well-known/oauth-protected-resource/mcp") |> json_response(200)
      assert suffixed["resource"] == base <> "/mcp"
    end

    test "an unauthenticated /mcp request gets a 401 pointing at the metadata", %{conn: conn} do
      conn = conn |> put_req_header("accept", "application/json") |> post("/mcp", %{})

      assert conn.status == 401
      [challenge] = get_resp_header(conn, "www-authenticate")

      assert challenge =~
               ~s(resource_metadata="#{MetricFlowWeb.Endpoint.url()}/.well-known/oauth-protected-resource/mcp")
    end
  end
end
