defmodule MetricFlowSpex.ModifyingSelectionFailsWhenPlatformAccessHasBeenRevokedSpex do
  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest

  spex "Modifying selection fails when platform access has been revoked", criterion: 574 do
    scenario "an integration whose platform token has expired or been revoked" do
      given_ "the user has an integration whose platform token has expired or been revoked",
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

      when_ "the user attempts to modify its selected accounts", context do
        result = live(context.owner_conn, "/app/integrations/connect/google_ads/accounts")
        {:ok, Map.put(context, :result, result)}
      end

      then_ "the change is rejected and the user is prompted to reconnect the platform instead",
            context do
        case context.result do
          {:ok, view, _html} ->
            refute has_element?(view, "[data-role='save-selection']")
            html = render(view)
            assert html =~ "reconnect" or html =~ "Reconnect"

          {:error, {:redirect, %{to: to}}} ->
            assert to =~ "connect"

          {:error, {:live_redirect, %{to: to}}} ->
            assert to =~ "connect"
        end

        {:ok, context}
      end
    end
  end
end
