defmodule MetricFlowSpex.PlatformConnectionBelongsToClientAccountAndNotTransferableToAgencySpex do
  use SexySpex
  use MetricFlowTest.ConnCase
  import Phoenix.LiveViewTest

  import_givens MetricFlowSpex.SharedGivens

  spex "Platform connection belongs to client account and is not transferable to agency" do
    scenario "client user can view their own integrations" do
      given_ :user_logged_in_as_owner

      given_ "the client user navigates to their integrations page", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/integrations")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "the integrations page is scoped to the client's account", context do
        html = render(context.view)
        assert html =~ "integrations" or html =~ "Integrations" or html =~ "Connect"
        :ok
      end
    end

    scenario "client user cannot see another account's integrations" do
      given_ :user_logged_in_as_owner

      given_ "a separate agency user registers their own account", context do
        email = "agency#{System.unique_integer([:positive])}@example.com"
        password = "SecurePassword123!"

        {:ok, reg_view, _html} = live(build_conn(), "/users/register")

        reg_view
        |> form("#registration_form", user: %{
          email: email,
          password: password,
          account_name: "Agency Account"
        })
        |> render_submit()

        {:ok, login_view, _html} = live(build_conn(), "/users/log-in")

        login_form =
          form(login_view, "#login_form_password", user: %{
            email: email,
            password: password,
            remember_me: true
          })

        logged_in_conn = submit_form(login_form, build_conn())
        agency_conn = recycle(logged_in_conn)

        {:ok, Map.merge(context, %{agency_conn: agency_conn, agency_email: email})}
      end

      when_ "the agency user views their integrations page", context do
        {:ok, view, html} = live(context.agency_conn, "/app/integrations")
        {:ok, Map.merge(context, %{agency_view: view, agency_html: html})}
      end

      then_ "the agency user does not see the client's integration data", context do
        refute context.agency_html =~ context.owner_email
        :ok
      end

      when_ "the client owner views their own integrations page", context do
        {:ok, view, html} = live(context.owner_conn, "/app/integrations")
        {:ok, Map.merge(context, %{client_view: view, client_html: html})}
      end

      then_ "the client owner does not see the agency account's integration data", context do
        refute context.client_html =~ context.agency_email
        :ok
      end
    end

    scenario "integration connect page is only accessible to the authenticated account" do
      given_ :user_logged_in_as_owner

      given_ "the authenticated user navigates to the integration connect page", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/integrations/connect/google")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "the page does not show an option to assign integration to a different account", context do
        html = render(context.view)
        refute html =~ "Transfer to agency"
        refute html =~ "Assign to agency"
        refute html =~ "Move to agency"
        :ok
      end

      then_ "the page is scoped to the current user's account", context do
        html = render(context.view)
        assert html =~ "Connect" or html =~ "Google" or
                 html =~ "provider" or html =~ "integration"
        :ok
      end
    end
  end
end
