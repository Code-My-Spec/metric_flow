defmodule MetricFlowSpex.AgencyCanConfigureDomainBasedAutoEnrollmentForTheirEmailDomainSpex do
  use SexySpex
  use MetricFlowTest.ConnCase
  import Phoenix.LiveViewTest

  import_givens MetricFlowSpex.SharedGivens

  spex "Agency can configure domain-based auto-enrollment for their email domain" do
    scenario "owner sees auto-enrollment configuration section on account settings page" do
      given_ :user_logged_in_as_owner

      given_ "the owner navigates to account settings", context do
        {:ok, view, _html} = live(context.owner_conn, "/accounts/settings")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "the owner sees an Auto-Enrollment section on the page", context do
        assert render(context.view) =~ "Auto-Enrollment"
        :ok
      end

      then_ "the owner sees a domain input field for auto-enrollment", context do
        assert has_element?(context.view, "[data-role='auto-enrollment-domain-input']")
        :ok
      end
    end

    scenario "owner can enter an email domain and save auto-enrollment settings" do
      given_ :user_logged_in_as_owner

      given_ "the owner navigates to account settings", context do
        {:ok, view, _html} = live(context.owner_conn, "/accounts/settings")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "the owner enters their company email domain and submits the form", context do
        context.view
        |> form("#auto-enrollment-form", auto_enrollment: %{
          domain: "myagency.com"
        })
        |> render_submit()

        {:ok, context}
      end

      then_ "a success confirmation is shown that auto-enrollment is enabled", context do
        assert render(context.view) =~ "Auto-enrollment enabled"
        :ok
      end
    end

    scenario "after saving, the configured domain is displayed on the settings page" do
      given_ :user_logged_in_as_owner

      given_ "the owner navigates to account settings", context do
        {:ok, view, _html} = live(context.owner_conn, "/accounts/settings")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "the owner saves the domain myagency.com for auto-enrollment", context do
        context.view
        |> form("#auto-enrollment-form", auto_enrollment: %{
          domain: "myagency.com"
        })
        |> render_submit()

        {:ok, context}
      end

      then_ "the configured domain myagency.com is displayed on the settings page", context do
        assert render(context.view) =~ "myagency.com"
        :ok
      end
    end
  end
end
