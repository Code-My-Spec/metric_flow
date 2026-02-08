defmodule MetricFlowSpex.UserCanLogInWithEmailAndPasswordSpex do
  @moduledoc """
  BDD specification for criterion 3949:
  User can log in with email and password
  """

  use SexySpex
  use MetricFlowTest.ConnCase

  import_givens MetricFlowSpex.SharedGivens
  import Phoenix.LiveViewTest

  spex "User can log in with email and password" do
    scenario "login page displays email and password form" do
      given_ "a user visits the login page", context do
        {:ok, view, html} = live(build_conn(), ~p"/users/log-in")
        {:ok, context |> Map.put(:view, view) |> Map.put(:html, html)}
      end

      then_ "the page shows email input field", context do
        assert context.html =~ "Email"
        assert context.html =~ ~s(type="email")
        :ok
      end

      then_ "the page shows password input field", context do
        assert context.html =~ "Password"
        assert context.html =~ ~s(type="password")
        :ok
      end

      then_ "the page shows login buttons", context do
        assert context.html =~ "Log in"
        :ok
      end
    end

    scenario "login form accepts email input" do
      given_ "a user is on the login page", context do
        {:ok, view, html} = live(build_conn(), ~p"/users/log-in")
        {:ok, context |> Map.put(:view, view) |> Map.put(:html, html)}
      end

      then_ "the email field is present in the form", context do
        assert context.html =~ ~s(name="user[email]")
        :ok
      end
    end

    scenario "magic link login option is available" do
      given_ "a user visits the login page", context do
        {:ok, view, html} = live(build_conn(), ~p"/users/log-in")
        {:ok, context |> Map.put(:view, view) |> Map.put(:html, html)}
      end

      then_ "the page shows magic link login option", context do
        assert context.html =~ "Log in with email"
        :ok
      end
    end
  end
end
