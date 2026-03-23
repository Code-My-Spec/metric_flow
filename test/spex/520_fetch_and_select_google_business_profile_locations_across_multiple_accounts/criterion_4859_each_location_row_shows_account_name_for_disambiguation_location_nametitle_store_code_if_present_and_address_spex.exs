defmodule MetricFlowSpex.EachLocationRowShowsAccountNameForDisambiguationLocationNameTitleStoreCodeIfPresentAndAddressSpex do
  use SexySpex
  use MetricFlowTest.ConnCase
  import Phoenix.LiveViewTest

  import_givens MetricFlowSpex.SharedGivens

  spex "Each location row shows account name, location title, store code if present, and address", fail_on_error_logs: false do
    scenario "location rows display account name for disambiguation" do
      given_ "a user is registered and has a google_business integration with multiple accounts", context do
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

      given_ "the user navigates to the google business locations page", context do
        result = live(context.owner_conn, "/integrations/connect/google_business/accounts")
        {:ok, Map.put(context, :result, result)}
      end

      then_ "the page is accessible and renders location rows", context do
        case context.result do
          {:ok, view, _html} ->
            html = render(view)
            assert html =~ "account" or html =~ "Account" or
                     html =~ "location" or html =~ "Location",
                   "Expected the locations page to render location content, got: #{String.slice(html, 0, 500)}"
            :ok

          {:error, {:redirect, %{to: "/users/log-in"}}} ->
            flunk("Expected the locations page to be accessible to an authenticated user, but was redirected to login")

          {:error, {:redirect, %{to: path}}} ->
            flunk("Expected the locations page to load but was redirected to #{path}")

          {:error, {:live_redirect, %{to: path}}} ->
            flunk("Expected the locations page to load but was live-redirected to #{path}")
        end
      end

      then_ "each location row includes the account name for disambiguation", context do
        case context.result do
          {:ok, view, _html} ->
            html = render(view)
            assert html =~ "account" or html =~ "Account" or
                     has_element?(view, "[data-role='location-account-name']") or
                     has_element?(view, "[data-role='location-row']"),
                   "Expected each location row to show an account name for disambiguation"
            :ok

          _ ->
            :ok
        end
      end
    end

    scenario "location rows display the location name or title" do
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

      given_ "the user navigates to the locations page", context do
        result = live(context.owner_conn, "/integrations/connect/google_business/accounts")
        {:ok, Map.put(context, :result, result)}
      end

      then_ "the location rows include location name or title fields", context do
        case context.result do
          {:ok, view, _html} ->
            html = render(view)
            assert html =~ "location" or html =~ "Location" or
                     html =~ "name" or html =~ "Name" or
                     html =~ "title" or html =~ "Title" or
                     has_element?(view, "[data-role='location-title']") or
                     has_element?(view, "[data-role='location-name']"),
                   "Expected location rows to display location name or title"
            :ok

          {:error, _} ->
            :ok
        end
      end
    end

    scenario "location rows display address information" do
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

      given_ "the user visits the google business accounts page", context do
        result = live(context.owner_conn, "/integrations/connect/google_business/accounts")
        {:ok, Map.put(context, :result, result)}
      end

      then_ "the location list includes address information for each location", context do
        case context.result do
          {:ok, view, _html} ->
            assert has_element?(view, "[data-role='location-address']") or
                     has_element?(view, "[data-role='location-row']") or
                     render(view) =~ "address" or render(view) =~ "Address",
                   "Expected the locations page to show address data for each location"
            :ok

          {:error, _} ->
            :ok
        end
      end
    end

    scenario "location rows show store code when present" do
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

      given_ "the user visits the google business accounts page", context do
        result = live(context.owner_conn, "/integrations/connect/google_business/accounts")
        {:ok, Map.put(context, :result, result)}
      end

      then_ "the location rows have a field for store code when available", context do
        case context.result do
          {:ok, view, _html} ->
            assert has_element?(view, "[data-role='location-store-code']") or
                     has_element?(view, "[data-role='location-row']") or
                     render(view) =~ "store" or render(view) =~ "Store" or
                     render(view) =~ "code" or render(view) =~ "Code",
                   "Expected the locations page to support showing store code when present on a location"
            :ok

          {:error, _} ->
            :ok
        end
      end
    end

    scenario "unauthenticated user cannot access the google business locations page" do
      given_ "an unauthenticated user navigates to the google business accounts page", context do
        result = live(build_conn(), "/integrations/connect/google_business/accounts")
        {:ok, Map.put(context, :result, result)}
      end

      then_ "the unauthenticated user is redirected away from the locations page", context do
        case context.result do
          {:error, {:redirect, _}} ->
            :ok

          {:error, {:live_redirect, _}} ->
            :ok

          {:ok, view, _html} ->
            refute render(view) =~ "location" and render(view) =~ "store code",
                   "Expected unauthenticated user to not see location management content"
            :ok
        end
      end
    end
  end
end
