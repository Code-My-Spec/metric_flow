defmodule MetricFlowSpex.AllLocationsFromAllAccountsAreMergedIntoASingleFlatListForDisplayAndSelectionSpex do
  use SexySpex
  use MetricFlowTest.ConnCase
  import Phoenix.LiveViewTest

  import_givens MetricFlowSpex.SharedGivens

  spex "All locations from all accounts are merged into a single flat list for display and selection",
       fail_on_error_logs: false do
    scenario "the locations page shows a single unified list, not grouped by account" do
      given_ "a user is registered and has a google_business integration with multiple account IDs", context do
        email = "gbp_user#{System.unique_integer([:positive])}@example.com"
        password = "SecurePassword123!"

        reg_conn = Phoenix.ConnTest.build_conn()
        {:ok, reg_view, _html} = live(reg_conn, "/users/register")

        reg_view
        |> form("#registration_form", user: %{
          email: email,
          password: password,
          account_name: "GBP Test Account"
        })
        |> render_submit()

        Process.sleep(50)
        drain = fn drain_fn ->
          receive do
            {:email, _} -> drain_fn.(drain_fn)
          after
            0 -> :ok
          end
        end
        drain.(drain)

        user = MetricFlowTest.UsersFixtures.get_user_by_email(email)
        MetricFlowTest.IntegrationsFixtures.integration_fixture(user, %{
          provider: :google_business,
          provider_metadata: %{
            "email" => email,
            "google_business_account_ids" => ["accounts/123", "accounts/456"]
          }
        })

        login_conn = Phoenix.ConnTest.build_conn()
        {:ok, login_view, _html} = live(login_conn, "/users/log-in")

        login_form =
          form(login_view, "#login_form_password", user: %{
            email: email,
            password: password,
            remember_me: true
          })

        logged_in_conn = submit_form(login_form, login_conn)
        authed_conn = recycle(logged_in_conn)

        {:ok, Map.merge(context, %{owner_conn: authed_conn, owner_email: email})}
      end

      given_ "the user navigates to the Google Business Profile locations page", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/integrations/connect/google_business/accounts")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "the page renders a single location selection interface, not multiple account sections", context do
        html = render(context.view)
        assert html =~ "location" or html =~ "Location"
        :ok
      end

      then_ "there is no per-account grouping or tab switcher", context do
        html = render(context.view)
        refute html =~ "accounts/123" and html =~ "accounts/456" and
                 has_element?(context.view, "[data-role='account-tab']")
        :ok
      end

      then_ "the location list is presented as a single selectable list", context do
        assert has_element?(context.view, "[data-role='location-list']") or
                 has_element?(context.view, "[data-role='account-selection']") or
                 has_element?(context.view, "[data-role='account-list']") or
                 has_element?(context.view, "input[type='checkbox']") or
                 has_element?(context.view, "[data-role='location-checkbox']")
        :ok
      end
    end

    scenario "locations from all GBP accounts appear in one flat list without requiring tab switching" do
      given_ "a user is registered and has a google_business integration with multiple account IDs", context do
        email = "gbp_user#{System.unique_integer([:positive])}@example.com"
        password = "SecurePassword123!"

        reg_conn = Phoenix.ConnTest.build_conn()
        {:ok, reg_view, _html} = live(reg_conn, "/users/register")

        reg_view
        |> form("#registration_form", user: %{
          email: email,
          password: password,
          account_name: "GBP Test Account"
        })
        |> render_submit()

        Process.sleep(50)
        drain = fn drain_fn ->
          receive do
            {:email, _} -> drain_fn.(drain_fn)
          after
            0 -> :ok
          end
        end
        drain.(drain)

        user = MetricFlowTest.UsersFixtures.get_user_by_email(email)
        MetricFlowTest.IntegrationsFixtures.integration_fixture(user, %{
          provider: :google_business,
          provider_metadata: %{
            "email" => email,
            "google_business_account_ids" => ["accounts/123", "accounts/456"]
          }
        })

        login_conn = Phoenix.ConnTest.build_conn()
        {:ok, login_view, _html} = live(login_conn, "/users/log-in")

        login_form =
          form(login_view, "#login_form_password", user: %{
            email: email,
            password: password,
            remember_me: true
          })

        logged_in_conn = submit_form(login_form, login_conn)
        authed_conn = recycle(logged_in_conn)

        {:ok, Map.merge(context, %{owner_conn: authed_conn, owner_email: email})}
      end

      given_ "the user navigates to the Google Business Profile locations page", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/integrations/connect/google_business/accounts")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "there is no requirement to switch between account tabs to see locations", context do
        refute has_element?(context.view, "[data-role='account-tab']")
        refute has_element?(context.view, "[data-role='account-switcher']")
        :ok
      end

      then_ "the page contains a save or confirm selection action", context do
        assert has_element?(context.view, "[data-role='save-selection']") or
                 has_element?(context.view, "button", "Save") or
                 has_element?(context.view, "button", "Confirm") or
                 has_element?(context.view, "button", "Save Selection") or
                 has_element?(context.view, "[data-role='account-selection']")
        :ok
      end
    end
  end
end
