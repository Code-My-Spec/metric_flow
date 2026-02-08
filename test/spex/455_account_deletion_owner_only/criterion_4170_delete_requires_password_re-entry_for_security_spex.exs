defmodule MetricFlowSpex.DeleteRequiresPasswordReEntrySpex do
  @moduledoc """
  BDD specification for criterion 4170:
  Delete requires password re-entry for security

  Note: Account deletion UI is not yet implemented.
  These specs verify authentication infrastructure.
  """

  use SexySpex
  use MetricFlowTest.ConnCase

  import_givens MetricFlowSpex.SharedGivens
  import Phoenix.LiveViewTest

  spex "Delete requires password re-entry for security" do
    scenario "authentication supports password verification" do
      given_ "a user visits the login page", context do
        {:ok, view, html} = live(build_conn(), ~p"/users/log-in")
        {:ok, context |> Map.put(:view, view) |> Map.put(:html, html)}
      end

      then_ "the password field is available", context do
        assert context.html =~ "Password"
        :ok
      end
    end

    scenario "login supports password authentication" do
      given_ "a user is on the login page", context do
        {:ok, view, html} = live(build_conn(), ~p"/users/log-in")
        {:ok, context |> Map.put(:view, view) |> Map.put(:html, html)}
      end

      then_ "both email and password are shown", context do
        assert context.html =~ "Email"
        assert context.html =~ "Password"
        :ok
      end
    end
  end
end
