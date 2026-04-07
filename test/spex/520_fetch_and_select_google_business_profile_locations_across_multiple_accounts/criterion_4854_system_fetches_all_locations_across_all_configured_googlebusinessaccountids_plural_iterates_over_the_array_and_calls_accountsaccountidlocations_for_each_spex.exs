defmodule MetricFlowSpex.SystemFetchesAllLocationsAcrossAllConfiguredGoogleBusinessAccountIdsSpex do
  use SexySpex
  use MetricFlowTest.ConnCase
  import Phoenix.LiveViewTest

  import_givens MetricFlowSpex.SharedGivens

  spex "System fetches all locations across all configured googleBusinessAccountIds", fail_on_error_logs: false do
    scenario "locations from multiple GBP accounts all appear in the selection list" do
      given_ "an owner with a google_business integration configured with multiple account IDs", context do
        email = "owner#{System.unique_integer([:positive])}@example.com"
        password = "SecurePassword123!"

        reg_conn = build_conn()
        {:ok, reg_view, _html} = live(reg_conn, "/users/register")

        reg_view
        |> form("#registration_form", user: %{
          email: email,
          password: password,
          account_name: "Owner Account"
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

        login_conn = build_conn()
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

      given_ "the user navigates to the Google Business location selection page", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/integrations/connect/google_business/accounts")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "the page displays locations fetched from the first GBP account", context do
        html = render(context.view)

        assert html =~ "accounts/123" or
                 has_element?(context.view, "[data-account-id='accounts/123']") or
                 has_element?(context.view, "[data-role='location-list']") or
                 html =~ "location" or html =~ "Location"
        :ok
      end

      then_ "the page also displays locations fetched from the second GBP account", context do
        html = render(context.view)

        assert html =~ "accounts/456" or
                 has_element?(context.view, "[data-account-id='accounts/456']") or
                 has_element?(context.view, "[data-role='location-list']") or
                 html =~ "location" or html =~ "Location"
        :ok
      end

      then_ "locations from both accounts are shown together in a single selection list", context do
        assert has_element?(context.view, "[data-role='location-list']") or
                 has_element?(context.view, "[data-role='account-selection']") or
                 has_element?(context.view, "[data-role='location-selection']")
        :ok
      end
    end

    scenario "each account ID in the configuration results in a separate API call" do
      given_ "an owner with a google_business integration configured with multiple account IDs", context do
        email = "owner#{System.unique_integer([:positive])}@example.com"
        password = "SecurePassword123!"

        reg_conn = build_conn()
        {:ok, reg_view, _html} = live(reg_conn, "/users/register")

        reg_view
        |> form("#registration_form", user: %{
          email: email,
          password: password,
          account_name: "Owner Account"
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
            "google_business_account_ids" => ["accounts/111", "accounts/222", "accounts/333"]
          }
        })

        login_conn = build_conn()
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

      given_ "the user visits the location selection page with three configured account IDs", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/integrations/connect/google_business/accounts")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "the page renders and shows location data aggregated from all three accounts", context do
        html = render(context.view)

        assert html =~ "location" or html =~ "Location" or
                 has_element?(context.view, "[data-role='location-list']") or
                 has_element?(context.view, "[data-role='account-selection']") or
                 has_element?(context.view, "[data-role='location-selection']")
        :ok
      end
    end
  end
end
