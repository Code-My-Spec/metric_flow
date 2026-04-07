defmodule MetricFlowSpex.AllUserAccessGrantsToThisAccountAreRevokedSpex do
  use SexySpex
  use MetricFlowTest.ConnCase
  import Phoenix.LiveViewTest

  import_givens MetricFlowSpex.SharedGivens

  spex "All user access grants to this account are revoked" do
    scenario "after account deletion, a member no longer sees the account in their accounts list" do
      given_ :user_logged_in_as_owner
      given_ :second_user_registered

      given_ "the second user has been invited as a member of the owner's account", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/accounts/members")

        view
        |> form("#invite_member_form", invitation: %{
          email: context.second_user_email,
          role: "account_manager"
        })
        |> render_submit()

        {:ok, context}
      end

      when_ "the owner deletes the account", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/accounts/settings")

        view
        |> form("#delete-account-form", delete_confirmation: %{
          account_name: "Owner Account",
          password: context.owner_password
        })
        |> render_submit()

        {:ok, context}
      end

      when_ "the second user logs in and visits the accounts list", context do
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
        {:ok, Map.put(context, :accounts_view, accounts_view)}
      end

      then_ "the deleted account is not listed for the second user", context do
        html = render(context.accounts_view)
        refute html =~ "Owner Account"
        :ok
      end
    end

    scenario "after account deletion, a member cannot access the deleted account" do
      given_ :user_logged_in_as_owner
      given_ :second_user_registered

      given_ "the second user has been invited as a member of the owner's account", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/accounts/members")

        view
        |> form("#invite_member_form", invitation: %{
          email: context.second_user_email,
          role: "account_manager"
        })
        |> render_submit()

        {:ok, context}
      end

      when_ "the owner deletes the account", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/accounts/settings")

        view
        |> form("#delete-account-form", delete_confirmation: %{
          account_name: "Owner Account",
          password: context.owner_password
        })
        |> render_submit()

        {:ok, context}
      end

      when_ "the second user logs in and visits the accounts page", context do
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
        {:ok, Map.put(context, :accounts_view, accounts_view)}
      end

      then_ "the deleted account does not appear and cannot be accessed", context do
        html = render(context.accounts_view)
        refute html =~ "Owner Account"
        :ok
      end
    end
  end
end
