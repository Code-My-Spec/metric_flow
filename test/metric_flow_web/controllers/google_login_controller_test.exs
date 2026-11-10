defmodule MetricFlowWeb.GoogleLoginControllerTest do
  use MetricFlowTest.ConnCase, async: false

  import MetricFlowTest.UsersFixtures
  alias MetricFlow.Users

  setup do
    Application.put_env(:metric_flow, :google_login_provider, MetricFlowTest.GoogleLoginStub)

    on_exit(fn ->
      Application.delete_env(:metric_flow, :google_login_provider)
      Application.delete_env(:metric_flow, :google_login_stub_user)
    end)
  end

  defp stub_user(attrs) do
    Application.put_env(
      :metric_flow,
      :google_login_stub_user,
      Map.merge(
        %{
          "sub" => "123",
          "email" => "g#{System.unique_integer([:positive])}@example.com",
          "email_verified" => true,
          "name" => "Gina Google"
        },
        attrs
      )
    )
  end

  defp start_login(conn, params \\ %{}) do
    conn = get(conn, ~p"/auth/google/login", params)
    url = redirected_to(conn, 302)
    {conn, URI.decode_query(URI.parse(url).query)["state"]}
  end

  test "login redirects to Google with a stored state", %{conn: conn} do
    {_conn, state} = start_login(conn)
    assert state =~ "stub-state"
  end

  test "login page and register page offer Continue with Google", %{conn: conn} do
    assert html_response(get(conn, ~p"/users/log-in"), 200) =~ "/auth/google/login"
    assert html_response(get(conn, ~p"/users/register"), 200) =~ "/auth/google/login"
  end

  test "new Google user is registered, confirmed, given an account and logged in", %{conn: conn} do
    stub_user(%{"email" => "new@example.com"})
    {conn, state} = start_login(conn)
    conn = get(conn, ~p"/auth/google/callback", %{"code" => "good", "state" => state})

    assert get_session(conn, :user_token)
    user = Users.get_user_by_email("new@example.com")
    assert user.confirmed_at
    assert user.account_name == "Gina Google"
    assert [_ | _] = MetricFlow.Accounts.list_accounts(MetricFlow.Users.Scope.for_user(user))
  end

  test "existing user is logged in without a duplicate", %{conn: conn} do
    user = user_fixture()
    stub_user(%{"email" => user.email})
    {conn, state} = start_login(conn)
    conn = get(conn, ~p"/auth/google/callback", %{"code" => "good", "state" => state})
    assert get_session(conn, :user_token)
    assert Users.get_user_by_email(user.email).id == user.id
  end

  test "honours a local return_to but not an external one", %{conn: conn} do
    stub_user(%{})
    {conn, state} = start_login(conn, %{"return_to" => "/app/reports"})
    conn = get(conn, ~p"/auth/google/callback", %{"code" => "good", "state" => state})
    assert redirected_to(conn) == "/app/reports"

    stub_user(%{})
    {conn, state} = start_login(build_conn(), %{"return_to" => "//evil.example"})
    conn = get(conn, ~p"/auth/google/callback", %{"code" => "good", "state" => state})
    refute redirected_to(conn) =~ "evil"
  end

  test "rejects an unverified Google email", %{conn: conn} do
    stub_user(%{"email" => "unv@example.com", "email_verified" => false})
    {conn, state} = start_login(conn)
    conn = get(conn, ~p"/auth/google/callback", %{"code" => "good", "state" => state})
    refute get_session(conn, :user_token)
    assert redirected_to(conn) == ~p"/users/log-in"
    refute Users.get_user_by_email("unv@example.com")
  end

  test "rejects unknown or replayed state, denial, and bad code", %{conn: conn} do
    stub_user(%{})
    c = get(conn, ~p"/auth/google/callback", %{"code" => "good", "state" => "forged"})
    refute get_session(c, :user_token)
    assert redirected_to(c) == ~p"/users/log-in"

    c = get(conn, ~p"/auth/google/callback", %{"error" => "access_denied"})
    assert redirected_to(c) == ~p"/users/log-in"

    {conn, state} = start_login(conn)
    c = get(conn, ~p"/auth/google/callback", %{"code" => "bad", "state" => state})
    refute get_session(c, :user_token)

    # state is consume-once
    c = get(conn, ~p"/auth/google/callback", %{"code" => "good", "state" => state})
    refute get_session(c, :user_token)
  end
end
