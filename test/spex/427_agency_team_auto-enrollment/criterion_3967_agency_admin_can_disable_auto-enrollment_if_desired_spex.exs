defmodule MetricFlowSpex.AgencyAdminCanDisableAutoEnrollmentIfDesiredSpex do
  use SexySpex
  use MetricFlowTest.ConnCase
  import Phoenix.LiveViewTest

  import_givens MetricFlowSpex.SharedGivens

  spex "Agency admin can disable auto-enrollment if desired" do
    scenario "agency admin sees a disable button or toggle when auto-enrollment is active" do
      given_ :user_logged_in_as_owner

      given_ "the owner has configured auto-enrollment for a unique domain", context do
        domain = "scenario1-#{System.unique_integer([:positive])}.com"
        {:ok, view, _html} = live(context.owner_conn, "/app/accounts/settings")

        view
        |> form("#auto-enrollment-form", auto_enrollment: %{
          domain: domain
        })
        |> render_submit()

        {:ok, Map.put(context, :settings_view, view)}
      end

      then_ "the settings page shows a control to disable auto-enrollment", context do
        html = render(context.settings_view)
        has_disable_button = has_element?(context.settings_view, "[data-role='disable-auto-enrollment']")
        has_disable_text = html =~ "Disable" or html =~ "disable"
        assert has_disable_button or has_disable_text,
          "Expected a disable auto-enrollment control to be present on the settings page"
        :ok
      end
    end

    scenario "agency admin can disable auto-enrollment from the settings page" do
      given_ :user_logged_in_as_owner

      given_ "the owner has configured auto-enrollment for a unique domain", context do
        domain = "scenario2-#{System.unique_integer([:positive])}.com"
        {:ok, view, _html} = live(context.owner_conn, "/app/accounts/settings")

        view
        |> form("#auto-enrollment-form", auto_enrollment: %{
          domain: domain
        })
        |> render_submit()

        {:ok, Map.put(context, :settings_view, view)}
      end

      when_ "the owner disables auto-enrollment", context do
        context.settings_view
        |> element("[data-role='disable-auto-enrollment']")
        |> render_click()

        {:ok, context}
      end

      then_ "a confirmation is shown that auto-enrollment has been disabled", context do
        assert render(context.settings_view) =~ "Auto-enrollment disabled"
        :ok
      end
    end

    scenario "after disabling auto-enrollment, a new user with matching domain is not auto-added" do
      given_ :user_logged_in_as_owner

      given_ "the owner has configured and then disabled auto-enrollment for a unique domain", context do
        domain = "scenario3-#{System.unique_integer([:positive])}.com"
        {:ok, view, _html} = live(context.owner_conn, "/app/accounts/settings")

        view
        |> form("#auto-enrollment-form", auto_enrollment: %{
          domain: domain
        })
        |> render_submit()

        view
        |> element("[data-role='disable-auto-enrollment']")
        |> render_click()

        {:ok, context |> Map.put(:settings_view, view) |> Map.put(:enrollment_domain, domain)}
      end

      when_ "a new user registers with an email matching the previously configured domain", context do
        newbie_email = "newbie#{System.unique_integer([:positive])}@#{context.enrollment_domain}"

        reg_conn = build_conn()
        {:ok, reg_view, _html} = live(reg_conn, "/users/register")

        reg_view
        |> form("#registration_form", user: %{
          email: newbie_email,
          password: "SecurePassword123!",
          account_name: "Newbie Account"
        })
        |> render_submit()

        {:ok, Map.put(context, :newbie_email, newbie_email)}
      end

      then_ "the new user does NOT appear as a member of the agency account", context do
        {:ok, members_view, _html} = live(context.owner_conn, "/app/accounts/members")
        html = render(members_view)
        refute html =~ context.newbie_email
        :ok
      end
    end
  end
end
