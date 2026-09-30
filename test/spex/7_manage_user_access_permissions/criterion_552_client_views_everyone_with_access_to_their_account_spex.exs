defmodule MetricFlowSpex.ClientViewsEveryoneWithAccessToTheirAccountSpex do
  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest

  import MetricFlowSpex.SharedGivens

  spex "Client views everyone with access to their account", criterion: 552 do
    scenario "Jordan sees teammates and Acme Agency together on the access management page" do
      given_ :user_logged_in_as_owner
      given_ :second_user_registered

      given_ "several teammates have access to Jordan's account", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/accounts/members")

        view
        |> form("#invite_member_form", invitation: %{
          email: context.second_user_email,
          role: "member"
        })
        |> render_submit()

        {:ok, context}
      end

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

        {:ok, Map.put(context, :acme_account_slug, MetricFlowSpex.Fixtures.personal_account_slug(email))}
      end

      given_ "Acme Agency has been granted access to Jordan's account", context do
        {:ok, settings_view, _html} = live(context.owner_conn, "/app/accounts/settings")

        settings_view
        |> form("#grant-agency-access-form", agency_access: %{
          slug: context.acme_account_slug,
          access_level: "read_only"
        })
        |> render_submit()

        {:ok, context}
      end

      when_ "Jordan opens the access management page", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/accounts/members")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "Jordan sees every user with access to the account", context do
        html = render(context.view)
        assert html =~ context.owner_email
        assert html =~ context.second_user_email
        {:ok, context}
      end

      then_ "Jordan also sees Acme Agency in the access list", context do
        assert render(context.view) =~ "Acme Agency"
        {:ok, context}
      end
    end
  end
end
