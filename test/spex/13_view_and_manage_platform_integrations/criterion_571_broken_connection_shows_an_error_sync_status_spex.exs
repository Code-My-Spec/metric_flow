defmodule MetricFlowSpex.BrokenConnectionShowsAnErrorSyncStatusSpex do
  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest

  spex "Broken connection shows an error sync status", criterion: 571 do
    scenario "an integration whose platform access has been revoked or expired" do
      given_ "the user has an integration whose platform access has been revoked or expired",
              context do
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

        user = MetricFlowTest.UsersFixtures.get_user_by_email(email)

        MetricFlowTest.IntegrationsFixtures.integration_fixture(user, %{
          provider: :google_ads,
          expires_at: DateTime.add(DateTime.utc_now(), -3600, :second)
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

      when_ "the user views the integrations list", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/integrations")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "the entry shows an error sync status instead of connected", context do
        assert has_element?(context.view, "[data-platform='google_ads'][data-status='error']")
        {:ok, context}
      end
    end
  end
end
