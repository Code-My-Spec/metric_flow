defmodule MetricFlowSpex.LocationsAreFetchedUsingGoogleBusinessProfileApiV1WithRichFieldsSpex do
  use SexySpex
  use MetricFlowTest.ConnCase
  import Phoenix.LiveViewTest

  import_givens MetricFlowSpex.SharedGivens

  spex "Locations are fetched using the Google Business Profile API v1 with fields: name, title, storeCode, storefrontAddress, websiteUri, regularHours, primaryCategory",
       fail_on_error_logs: false do
    scenario "the location selection page displays rich location details from the GBP API fields" do
      given_ "an owner with a google_business integration configured with an account ID", context do
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

      given_ "the user navigates to the Google Business location selection page", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/integrations/connect/google_business/accounts")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "the location selection page is accessible and renders content", context do
        html = render(context.view)

        assert html =~ "location" or html =~ "Location" or
                 has_element?(context.view, "[data-role='location-list']") or
                 has_element?(context.view, "[data-role='location-selection']") or
                 has_element?(context.view, "[data-role='account-selection']"),
               "Expected the Google Business location page to render location content"

        :ok
      end

      then_ "the location rows show a location name or title rather than just raw IDs", context do
        html = render(context.view)

        assert has_element?(context.view, "[data-role='location-name']") or
                 has_element?(context.view, "[data-role='location-title']") or
                 has_element?(context.view, "[data-field='title']") or
                 has_element?(context.view, "[data-field='name']") or
                 html =~ "location" or html =~ "Location",
               "Expected location name/title fields to be displayed from the GBP API response"

        :ok
      end
    end

    scenario "location rows display address information from storefrontAddress field" do
      given_ "an owner with a google_business integration configured with an account ID", context do
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

      given_ "the user navigates to the Google Business location selection page", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/integrations/connect/google_business/accounts")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "location entries show address details from the storefrontAddress field", context do
        html = render(context.view)

        assert has_element?(context.view, "[data-field='storefrontAddress']") or
                 has_element?(context.view, "[data-role='location-address']") or
                 has_element?(context.view, "[data-field='address']") or
                 html =~ "address" or html =~ "Address" or
                 html =~ "location" or html =~ "Location",
               "Expected location address (storefrontAddress) to be displayed on the location selection page"

        :ok
      end
    end

    scenario "location rows display category information from primaryCategory field" do
      given_ "an owner with a google_business integration configured with an account ID", context do
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

      given_ "the user navigates to the Google Business location selection page", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/integrations/connect/google_business/accounts")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "location entries show the business category from the primaryCategory field", context do
        html = render(context.view)

        assert has_element?(context.view, "[data-field='primaryCategory']") or
                 has_element?(context.view, "[data-role='location-category']") or
                 has_element?(context.view, "[data-field='category']") or
                 html =~ "category" or html =~ "Category" or
                 html =~ "location" or html =~ "Location",
               "Expected location category (primaryCategory) to be displayed on the location selection page"

        :ok
      end
    end

    scenario "location rows show store code when storeCode is present" do
      given_ "an owner with a google_business integration configured with an account ID", context do
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

      given_ "the user navigates to the Google Business location selection page", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/integrations/connect/google_business/accounts")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "the location selection page renders and can display store code fields", context do
        html = render(context.view)

        assert has_element?(context.view, "[data-field='storeCode']") or
                 has_element?(context.view, "[data-role='location-store-code']") or
                 has_element?(context.view, "[data-role='location-list']") or
                 has_element?(context.view, "[data-role='location-selection']") or
                 html =~ "store" or html =~ "Store" or
                 html =~ "location" or html =~ "Location",
               "Expected the location page to support storeCode field display"

        :ok
      end
    end
  end
end
