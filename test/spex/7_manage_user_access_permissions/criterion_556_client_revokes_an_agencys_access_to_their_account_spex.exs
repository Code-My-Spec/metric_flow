defmodule MetricFlowSpex.ClientRevokesAnAgencysAccessToTheirAccountSpex do
  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest

  import MetricFlowSpex.SharedGivens

  spex "Client revokes an agency's access to their account", criterion: 556 do
    scenario "Jordan revokes Acme Agency's access to his account" do
      given_ :user_logged_in_as_owner

      given_ "Acme Agency exists", context do
        email = "acme#{System.unique_integer([:positive])}@example.com"
        password = "SecurePassword123!"

        reg_conn = build_conn()
        {:ok, reg_view, _html} = live(reg_conn, "/users/register")

        reg_view
        |> form("#registration_form",
          user: %{
            email: email,
            password: password,
            account_name: "Acme Agency",
            account_type: "agency"
          }
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

        {:ok,
         context
         |> Map.put(:acme_account_id, MetricFlowSpex.Fixtures.personal_account_id(email))
         |> Map.put(:acme_account_slug, MetricFlowSpex.Fixtures.personal_account_slug(email))}
      end

      given_ "Acme Agency currently has access to Jordan's account data", context do
        {:ok, settings_view, _html} = live(context.owner_conn, "/app/accounts/settings")

        settings_view
        |> form("#grant-agency-access-form", agency_access: %{
          slug: context.acme_account_slug,
          access_level: "read_only"
        })
        |> render_submit()

        {:ok, Map.put(context, :settings_view, settings_view)}
      end

      then_ "Acme Agency appears in the access list before revocation", context do
        assert render(context.settings_view) =~ "Acme Agency"
        {:ok, context}
      end

      when_ "Jordan revokes Acme Agency's access", context do
        context.settings_view
        |> element("[data-role='revoke-agency-access'][phx-value-agency-account-id='#{context.acme_account_id}']")
        |> render_click()

        {:ok, context}
      end

      then_ "Acme Agency no longer has access", context do
        refute render(context.settings_view) =~ "Acme Agency"
        {:ok, context}
      end
    end
  end
end
