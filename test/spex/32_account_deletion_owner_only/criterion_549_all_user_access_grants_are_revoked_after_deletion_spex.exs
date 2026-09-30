defmodule MetricFlowSpex.AllUserAccessGrantsAreRevokedAfterDeletionSpex do
  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest

  import MetricFlowSpex.SharedGivens

  spex "All user access grants are revoked after deletion", criterion: 549 do
    scenario "other users with access lose it once the account is deleted" do
      given_ :user_logged_in_as_owner
      given_ :second_user_registered

      given_ "the account has another user with access", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/accounts/members")

        view
        |> form("#invite_member_form", invitation: %{
          email: context.second_user_email,
          role: "account_manager"
        })
        |> render_submit()

        {:ok, context}
      end

      when_ "the account is deleted", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/accounts/settings")

        view
        |> form("#delete-account-form", delete_confirmation: %{
          account_name: "Owner Account",
          password: context.owner_password
        })
        |> render_submit()

        {:ok, context}
      end

      then_ "every user's access grant to that account is revoked", context do
        {:ok, login_view, _html} = live(build_conn(), "/users/log-in")

        login_form =
          form(login_view, "#login_form_password", user: %{
            email: context.second_user_email,
            password: context.second_user_password,
            remember_me: true
          })

        logged_in_conn = submit_form(login_form, build_conn())
        member_conn = recycle(logged_in_conn)
        {:ok, accounts_view, _html} = live(member_conn, "/app/accounts")

        refute render(accounts_view) =~ "Owner Account"
        {:ok, context}
      end
    end
  end
end
