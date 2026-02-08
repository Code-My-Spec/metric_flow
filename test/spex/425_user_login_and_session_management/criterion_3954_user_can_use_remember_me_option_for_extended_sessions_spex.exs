defmodule MetricFlowSpex.UserCanUseRememberMeOptionForExtendedSessionsSpex do
  @moduledoc """
  BDD specification for criterion 3954:
  User can use Remember me option for extended sessions
  """

  use SexySpex
  use MetricFlowTest.ConnCase

  import_givens MetricFlowSpex.SharedGivens
  import Phoenix.LiveViewTest

  spex "User can use Remember me option for extended sessions" do
    scenario "login form includes remember me option" do
      given_ "a user visits the login page", context do
        {:ok, view, html} = live(build_conn(), ~p"/users/log-in")
        {:ok, context |> Map.put(:view, view) |> Map.put(:html, html)}
      end

      then_ "the page shows a stay logged in option", context do
        assert context.html =~ "stay logged in"
        :ok
      end
    end

    scenario "password login offers persistent session option" do
      given_ "a user is on the login page", context do
        {:ok, view, html} = live(build_conn(), ~p"/users/log-in")
        {:ok, context |> Map.put(:view, view) |> Map.put(:html, html)}
      end

      then_ "the password form has remember me functionality", context do
        assert context.html =~ "Log in and stay logged in"
        :ok
      end
    end

    scenario "non-persistent login option is also available" do
      given_ "a user visits the login page", context do
        {:ok, view, html} = live(build_conn(), ~p"/users/log-in")
        {:ok, context |> Map.put(:view, view) |> Map.put(:html, html)}
      end

      then_ "the page shows a temporary login option", context do
        assert context.html =~ "Log in only this time"
        :ok
      end
    end

    scenario "both session options are clearly presented" do
      given_ "a user is on the login page", context do
        {:ok, view, html} = live(build_conn(), ~p"/users/log-in")
        {:ok, context |> Map.put(:view, view) |> Map.put(:html, html)}
      end

      then_ "the user can choose between persistent and temporary login", context do
        assert context.html =~ "stay logged in"
        assert context.html =~ "only this time"
        :ok
      end
    end
  end
end
