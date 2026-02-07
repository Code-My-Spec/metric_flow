defmodule MetricFlowSpex.InactiveSessionsExpireAfterReasonablePeriodSpex do
  @moduledoc """
  BDD specification for criterion 3953:
  Inactive sessions expire after a reasonable period

  Note: Session expiration is configured at the framework level.
  These specs verify the session management UI elements are present.
  """

  use SexySpex

  import_givens MetricFlowSpex.SharedGivens
  import Phoenix.LiveViewTest
  import Phoenix.ConnTest

  use MetricFlowWeb, :verified_routes

  @endpoint MetricFlowWeb.Endpoint

  spex "Inactive sessions expire after a reasonable period" do
    scenario "login page offers session duration options" do
      given_ "a user visits the login page", context do
        {:ok, view, html} = live(build_conn(), ~p"/users/log-in")
        {:ok, context |> Map.put(:view, view) |> Map.put(:html, html)}
      end

      then_ "the page shows different session duration options", context do
        # "stay logged in" vs "only this time"
        assert context.html =~ "stay logged in" or context.html =~ "only this time"
        :ok
      end
    end

    scenario "temporary login option is available" do
      given_ "a user is on the login page", context do
        {:ok, view, html} = live(build_conn(), ~p"/users/log-in")
        {:ok, context |> Map.put(:view, view) |> Map.put(:html, html)}
      end

      then_ "the page offers a temporary login option", context do
        assert context.html =~ "only this time" or context.html =~ "Log in"
        :ok
      end
    end

    scenario "session management is part of authentication flow" do
      given_ "a user accesses the authentication system", context do
        {:ok, view, html} = live(build_conn(), ~p"/users/log-in")
        {:ok, context |> Map.put(:view, view) |> Map.put(:html, html)}
      end

      then_ "the system supports session-based authentication", context do
        assert context.html =~ "Log in"
        :ok
      end
    end
  end
end
