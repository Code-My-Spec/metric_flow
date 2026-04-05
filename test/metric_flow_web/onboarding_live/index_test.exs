defmodule MetricFlowWeb.OnboardingLive.IndexTest do
  use MetricFlowTest.ConnCase, async: false

  import ExUnit.CaptureLog
  import Phoenix.LiveViewTest
  import MetricFlowTest.UsersFixtures

  # ---------------------------------------------------------------------------
  # mount/3
  # ---------------------------------------------------------------------------

  describe "mount/3" do
    test "renders welcome heading for authenticated user", %{conn: conn} do
      user = user_fixture()
      conn = log_in_user(conn, user)

      capture_log(fn ->
        {:ok, _lv, html} = live(conn, ~p"/onboarding")

        assert html =~ "Welcome to MetricFlow"
        send(self(), :done)
      end)

      assert_receive :done
    end

    test "redirects unauthenticated user to login", %{conn: conn} do
      assert {:error, {:redirect, %{to: "/users/log-in"}}} =
               live(conn, ~p"/onboarding")
    end
  end

  # ---------------------------------------------------------------------------
  # render/1
  # ---------------------------------------------------------------------------

  describe "render/1" do
    test "displays \"Welcome to MetricFlow\" heading", %{conn: conn} do
      user = user_fixture()
      conn = log_in_user(conn, user)

      capture_log(fn ->
        {:ok, _lv, html} = live(conn, ~p"/onboarding")

        assert html =~ "Welcome to MetricFlow"
        send(self(), :done)
      end)

      assert_receive :done
    end

    test "renders introductory setup text", %{conn: conn} do
      user = user_fixture()
      conn = log_in_user(conn, user)

      capture_log(fn ->
        {:ok, _lv, html} = live(conn, ~p"/onboarding")

        assert html =~ "get started setting up your account"
        send(self(), :done)
      end)

      assert_receive :done
    end
  end
end
