defmodule MetricFlowWeb.YouTubeOauthSecurityTest do
  use MetricFlowTest.ConnCase, async: false

  import MetricFlowTest.UsersFixtures
  alias MetricFlow.Accounts
  alias MetricFlow.Integrations
  alias MetricFlow.Users.Scope

  setup %{conn: conn} do
    user = user_fixture()
    scope = Scope.for_user(user)

    {:ok, account} =
      Accounts.create_team_account(scope, %{
        name: "YouTube owner",
        slug: "youtube-security-#{System.unique_integer([:positive])}"
      })

    originals =
      for key <- [:oauth_providers, :req_http_options],
          do: {key, Application.fetch_env(:metric_flow, key)}

    on_exit(fn ->
      for {key, value} <- originals do
        case value do
          {:ok, original} -> Application.put_env(:metric_flow, key, original)
          :error -> Application.delete_env(:metric_flow, key)
        end
      end
    end)

    Application.put_env(:metric_flow, :oauth_providers, %{
      youtube: MetricFlowTest.YouTubeOAuthProvider
    })

    Application.put_env(:metric_flow, :req_http_options,
      plug: &MetricFlowTest.YouTubeOAuthProvider.respond/1
    )

    %{conn: log_in_user(conn, user), scope: Scope.put_account_id(scope, account.id)}
  end

  defp begin_oauth(conn) do
    request = get(conn, ~p"/app/integrations/oauth/youtube")
    params = request |> redirected_to() |> URI.parse() |> Map.fetch!(:query) |> URI.decode_query()
    {recycle(request), params["state"]}
  end

  test "missing state cannot establish pending credentials", %{conn: conn, scope: scope} do
    response =
      get(conn, ~p"/app/integrations/oauth/callback/youtube", %{"code" => "synthetic-code"})

    assert redirected_to(response) == ~p"/app/integrations/connect/youtube"
    assert is_nil(get_session(response, :youtube_pending_authorization))
    assert {:error, :not_found} = Integrations.get_integration(scope, :youtube)
  end

  test "switching accounts invalidates the initiating account's callback", %{
    conn: conn,
    scope: scope
  } do
    {conn, state} = begin_oauth(conn)

    {:ok, other} =
      Accounts.create_team_account(scope, %{
        name: "Other account",
        slug: "youtube-other-#{System.unique_integer([:positive])}"
      })

    Accounts.touch_membership(scope, other.id)

    response =
      get(conn, ~p"/app/integrations/oauth/callback/youtube", %{
        "code" => "synthetic-code",
        "state" => state
      })

    assert redirected_to(response) == ~p"/app/integrations/connect/youtube"
    assert is_nil(get_session(response, :youtube_pending_authorization))
    assert {:error, :not_found} = Integrations.get_integration(scope, :youtube)

    assert {:error, :not_found} =
             Integrations.get_integration(Scope.put_account_id(scope, other.id), :youtube)
  end

  test "pending credentials reject another user and unknown channels before saving", %{
    conn: conn,
    scope: scope
  } do
    {conn, state} = begin_oauth(conn)

    response =
      get(conn, ~p"/app/integrations/oauth/callback/youtube", %{
        "code" => "synthetic-code",
        "state" => state
      })

    assert redirected_to(response) == ~p"/app/integrations/connect/youtube/accounts"
    token = get_session(response, :youtube_pending_authorization)
    assert is_binary(token)
    assert {:error, :not_found} = Integrations.get_integration(scope, :youtube)

    teammate = user_fixture()

    assert {:ok, _} =
             Accounts.add_user_to_account(scope, teammate.id, scope.account_id, :account_manager)

    teammate_scope = Scope.for_user(teammate) |> Scope.put_account_id(scope.account_id)
    assert {:error, :not_found} = Integrations.youtube_selection(teammate_scope, token)

    assert {:error, :invalid_channel_selection} =
             Integrations.save_youtube_channels(scope, token, ["unavailable"])

    assert {:error, :not_found} = Integrations.get_integration(scope, :youtube)
    assert {:ok, saved} = Integrations.save_youtube_channels(scope, token, ["UC_dana_personal"])
    assert saved.account_id == scope.account_id

    replay =
      get(recycle(response), ~p"/app/integrations/oauth/callback/youtube", %{
        "code" => "synthetic-code",
        "state" => state
      })

    assert redirected_to(replay) == ~p"/app/integrations/connect/youtube"
    assert is_nil(get_session(replay, :youtube_pending_authorization))
  end
end
