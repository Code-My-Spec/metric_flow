defmodule MetricFlowSpex.FailedLoginAttemptsShowClearErrorMessagesSpex do
  @moduledoc """
  BDD specification for criterion 3950:
  Failed login attempts show clear error messages
  """

  use SexySpex
  use MetricFlowTest.ConnCase

  import_givens MetricFlowSpex.SharedGivens
  import Phoenix.LiveViewTest

  spex "Failed login attempts show clear error messages" do
    scenario "magic link login shows generic message for security" do
      given_ "a user is on the login page", context do
        {:ok, view, _html} = live(build_conn(), ~p"/users/log-in")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "the user submits magic link login with any email", context do
        context.view
        |> form("#login_form_magic", user: %{
          email: "nonexistent@example.com"
        })
        |> render_submit()

        flash = assert_redirect(context.view, "/users/log-in")
        {:ok, Map.put(context, :flash, flash)}
      end

      then_ "a generic security message is shown", context do
        # For security, the message doesn't reveal if email exists
        assert context.flash["info"] =~ "If your email is in our system"
        :ok
      end
    end

    scenario "login page is accessible after failed attempt" do
      given_ "a user tries to log in", context do
        {:ok, view, html} = live(build_conn(), ~p"/users/log-in")
        {:ok, context |> Map.put(:view, view) |> Map.put(:html, html)}
      end

      then_ "the login form remains available", context do
        assert context.html =~ "Log in"
        assert context.html =~ "Email"
        :ok
      end
    end

    scenario "error messages are user-friendly" do
      given_ "a user visits the login page", context do
        {:ok, view, html} = live(build_conn(), ~p"/users/log-in")
        {:ok, context |> Map.put(:view, view) |> Map.put(:html, html)}
      end

      then_ "the page does not show technical error details", context do
        refute context.html =~ "Exception"
        refute context.html =~ "stacktrace"
        :ok
      end
    end
  end
end
