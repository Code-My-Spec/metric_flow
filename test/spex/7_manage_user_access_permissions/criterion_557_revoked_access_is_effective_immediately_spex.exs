defmodule MetricFlowSpex.RevokedAccessIsEffectiveImmediatelySpex do
  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest

  import MetricFlowSpex.SharedGivens

  spex "Revoked access is effective immediately", criterion: 557 do
    scenario "a user whose access was just revoked is immediately denied access to Jordan's account" do
      given_ :user_logged_in_as_owner
      given_ :second_user_registered

      given_ "the second user has access to Jordan's account", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/accounts/members")

        view
        |> form("#invite_member_form", invitation: %{
          email: context.second_user_email,
          role: "read_only"
        })
        |> render_submit()

        {:ok, view2, _html2} = live(build_conn(), "/users/log-in")

        login_form =
          form(view2, "#login_form_password", user: %{
            email: context.second_user_email,
            password: context.second_user_password,
            remember_me: true
          })

        second_conn = submit_form(login_form, build_conn()) |> recycle()

        {:ok, Map.put(context, :members_view, view) |> Map.put(:second_conn, second_conn)}
      end

      then_ "Jordan's account is visible to the second user before revocation", context do
        {:ok, accounts_view, _html} = live(context.second_conn, "/app/accounts")
        assert render(accounts_view) =~ "Owner Account"
        {:ok, context}
      end

      when_ "the second user's access to Jordan's account was just revoked", context do
        context.members_view
        |> element("[data-role='remove-member'][data-user-email='#{context.second_user_email}']")
        |> render_click()

        {:ok, context}
      end

      then_ "the second user is denied immediately when attempting to view Jordan's data", context do
        {:ok, accounts_view, _html} = live(context.second_conn, "/app/accounts")
        refute render(accounts_view) =~ "Owner Account"
        {:ok, context}
      end
    end
  end
end
