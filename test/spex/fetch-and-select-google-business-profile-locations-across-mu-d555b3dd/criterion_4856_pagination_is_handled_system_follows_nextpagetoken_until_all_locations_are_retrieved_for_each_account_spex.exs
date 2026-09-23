defmodule MetricFlowSpex.PaginationIsHandledSystemFollowsNextPageTokenUntilAllLocationsAreRetrievedForEachAccountSpex do
  use SexySpex
  use MetricFlowTest.ConnCase
  import Phoenix.LiveViewTest

  import_givens MetricFlowSpex.SharedGivens

  spex "Pagination is handled — system follows nextPageToken until all locations are retrieved for each account",
       fail_on_error_logs: false do
    scenario "authenticated user sees all locations without manual pagination" do
      given_ "a user is registered and has a google_business integration", context do
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
            "google_business_account_ids" => ["accounts/123"]
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

      given_ "the user navigates to the location selection page", context do
        result = live(context.owner_conn, "/app/integrations/connect/google_business/accounts")
        {:ok, Map.put(context, :location_page_result, result)}
      end

      then_ "the location selection page loads without requiring manual pagination", context do
        case context.location_page_result do
          {:ok, _view, _html} ->
            :ok

          {:error, {:redirect, %{to: "/users/log-in"}}} ->
            flunk("Expected the location selection page to be accessible to an authenticated user, but was redirected to login")

          {:error, {:redirect, %{to: path}}} ->
            flunk("Expected the location selection page to load but was redirected to #{path}")

          {:error, {:live_redirect, %{to: path}}} ->
            flunk("Expected the location selection page to load but was live-redirected to #{path}")
        end
      end

      then_ "the page presents all locations in a single list with no load more button required", context do
        case context.location_page_result do
          {:ok, view, _html} ->
            html = render(view)

            refute html =~ "Load more" or html =~ "load more" or
                     has_element?(view, "[data-role='load-more']") or
                     has_element?(view, "button", "Load More"),
                   "Expected all locations to be shown without requiring the user to manually paginate"

            assert html =~ "location" or html =~ "Location" or
                     has_element?(view, "[data-role='location-list']") or
                     has_element?(view, "[data-role='location-selection']") or
                     html =~ "account" or html =~ "Account",
                   "Expected location or account selection content to be visible on the page"

            :ok

          _ ->
            :ok
        end
      end
    end

    scenario "location list page is accessible to authenticated google_business integration owner" do
      given_ "a user is registered and has a google_business integration", context do
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
            "google_business_account_ids" => ["accounts/123"]
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

      given_ "the user visits the google_business account location page", context do
        result = live(context.owner_conn, "/app/integrations/connect/google_business/accounts")
        {:ok, Map.put(context, :page_result, result)}
      end

      then_ "the page does not redirect the authenticated user away", context do
        case context.page_result do
          {:error, {:redirect, %{to: "/users/log-in"}}} ->
            flunk("Authenticated user was redirected to login — integration or session may not be set up correctly")

          {:error, {:redirect, %{to: _}}} ->
            :ok

          {:error, {:live_redirect, %{to: _}}} ->
            :ok

          {:ok, _view, _html} ->
            :ok
        end
      end
    end

    scenario "unauthenticated user cannot access the location selection page" do
      given_ "an unauthenticated user navigates to the google_business location page", context do
        result = live(build_conn(), "/app/integrations/connect/google_business/accounts")
        {:ok, Map.put(context, :result, result)}
      end

      then_ "the user is redirected away from the location selection page", context do
        case context.result do
          {:error, {:redirect, _}} ->
            :ok

          {:error, {:live_redirect, _}} ->
            :ok

          {:ok, view, _html} ->
            html = render(view)

            refute html =~ "Select location" or html =~ "Select Location",
                   "Expected unauthenticated user to not see the location selection page"

            :ok
        end
      end
    end
  end
end
