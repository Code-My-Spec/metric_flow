defmodule MetricFlowSpex.IfALocationDisappearsFromTheApiItIsFlaggedInTheUiRatherThanSilentlyRemovedFromSyncConfigSpex do
  use SexySpex
  use MetricFlowTest.ConnCase
  import Phoenix.LiveViewTest

  import_givens MetricFlowSpex.SharedGivens

  spex "If a location disappears from the API (e.g. deleted or access revoked), it is flagged in the UI rather than silently removed from sync config",
       fail_on_error_logs: false do
    scenario "a previously selected location no longer returned by the API is flagged in the UI" do
      given_ "a user registered with a google_business integration that has a now-missing selected location", context do
        email = "owner#{System.unique_integer([:positive])}@example.com"
        password = "SecurePassword123!"

        reg_conn = build_conn()
        {:ok, reg_view, _html} = live(reg_conn, "/users/register")

        reg_view
        |> form("#registration_form",
          user: %{email: email, password: password, account_name: "Owner Account"}
        )
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
            "google_business_account_ids" => ["accounts/123"],
            "included_locations" => ["accounts/123/locations/deleted-loc-1"]
          }
        })

        login_conn = build_conn()
        {:ok, login_view, _html} = live(login_conn, "/users/log-in")

        login_form =
          form(login_view, "#login_form_password",
            user: %{email: email, password: password, remember_me: true}
          )

        logged_in_conn = submit_form(login_form, login_conn)
        authed_conn = recycle(logged_in_conn)

        {:ok, Map.merge(context, %{owner_conn: authed_conn, owner_email: email})}
      end

      given_ "the user navigates to the Google Business location selection page", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/integrations/connect/google_business/accounts")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "the page shows a visual warning or flag for the missing location rather than silently removing it", context do
        html = render(context.view)

        flagged =
          html =~ "deleted-loc-1" or
            html =~ "missing" or html =~ "Missing" or
            html =~ "unavailable" or html =~ "Unavailable" or
            html =~ "not found" or html =~ "Not found" or
            html =~ "removed" or html =~ "Removed" or
            html =~ "revoked" or html =~ "Revoked" or
            html =~ "warning" or html =~ "Warning" or
            has_element?(context.view, "[data-role='missing-location']") or
            has_element?(context.view, "[data-role='location-warning']") or
            has_element?(context.view, "[data-role='location-unavailable']") or
            has_element?(context.view, ".location-missing") or
            has_element?(context.view, ".location-warning")

        assert flagged,
               "Expected the UI to flag the missing location 'accounts/123/locations/deleted-loc-1' with a warning or indicator, but no such element was found. HTML: #{html}"

        :ok
      end
    end

    scenario "the missing location warning does not silently drop the location from config" do
      given_ "a user registered with a google_business integration that references a deleted location", context do
        email = "owner#{System.unique_integer([:positive])}@example.com"
        password = "SecurePassword123!"

        reg_conn = build_conn()
        {:ok, reg_view, _html} = live(reg_conn, "/users/register")

        reg_view
        |> form("#registration_form",
          user: %{email: email, password: password, account_name: "Owner Account"}
        )
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
            "google_business_account_ids" => ["accounts/123"],
            "included_locations" => ["accounts/123/locations/deleted-loc-1"]
          }
        })

        login_conn = build_conn()
        {:ok, login_view, _html} = live(login_conn, "/users/log-in")

        login_form =
          form(login_view, "#login_form_password",
            user: %{email: email, password: password, remember_me: true}
          )

        logged_in_conn = submit_form(login_form, login_conn)
        authed_conn = recycle(logged_in_conn)

        {:ok, Map.merge(context, %{owner_conn: authed_conn, owner_email: email})}
      end

      given_ "the user visits the location selection page", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/integrations/connect/google_business/accounts")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "the page still renders the previously configured location ID in some form rather than being absent", context do
        html = render(context.view)

        # The location should appear in the rendered HTML in some form —
        # either shown as a warning entry, strikethrough, badge, or alert —
        # confirming it has NOT been silently dropped from the display.
        location_present =
          html =~ "deleted-loc-1" or
            html =~ "accounts/123/locations" or
            has_element?(context.view, "[data-role='missing-location']") or
            has_element?(context.view, "[data-role='location-warning']") or
            has_element?(context.view, "[data-role='stale-location']") or
            has_element?(context.view, "[data-location-id='accounts/123/locations/deleted-loc-1']")

        assert location_present,
               "Expected the previously configured location to be visible in the UI with a flag, but it was absent entirely. HTML: #{html}"

        :ok
      end
    end
  end
end
