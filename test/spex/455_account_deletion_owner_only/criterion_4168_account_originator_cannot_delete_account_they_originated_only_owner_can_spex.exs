defmodule MetricFlowSpex.AccountOriginatorCannotDeleteAccountTheyOriginatedSpex do
  use SexySpex
  use MetricFlowTest.ConnCase
  import Phoenix.LiveViewTest

  import_givens MetricFlowSpex.SharedGivens

  spex "Account originator cannot delete account they originated (only owner can)" do
    scenario "originator who transferred ownership cannot see delete account section" do
      given_ :user_logged_in_as_owner
      given_ :second_user_registered

      given_ "the originator invites the second user as admin", context do
        {:ok, view, _html} = live(context.owner_conn, "/accounts/members")

        view
        |> form("#invite_member_form", invitation: %{
          email: context.second_user_email,
          role: "admin"
        })
        |> render_submit()

        {:ok, context}
      end

      given_ "the originator transfers ownership to the second user", context do
        {:ok, view, _html} = live(context.owner_conn, "/accounts/settings")

        view
        |> element("[data-role='transfer-ownership']")
        |> render_submit(%{transfer_ownership: %{new_owner_email: context.second_user_email}})

        {:ok, context}
      end

      given_ "the originator navigates to account settings after the transfer", context do
        {:ok, view, _html} = live(context.owner_conn, "/accounts/settings")
        {:ok, Map.put(context, :originator_view, view)}
      end

      then_ "the originator cannot see the delete account section", context do
        refute has_element?(context.originator_view, "[data-role='delete-account']")
        :ok
      end
    end

    scenario "new owner who received transferred ownership can see delete account section" do
      given_ :user_logged_in_as_owner
      given_ :second_user_registered

      given_ "the originator invites the second user as admin", context do
        {:ok, view, _html} = live(context.owner_conn, "/accounts/members")

        view
        |> form("#invite_member_form", invitation: %{
          email: context.second_user_email,
          role: "admin"
        })
        |> render_submit()

        {:ok, context}
      end

      given_ "the originator transfers ownership to the second user", context do
        {:ok, view, _html} = live(context.owner_conn, "/accounts/settings")

        view
        |> element("[data-role='transfer-ownership']")
        |> render_submit(%{transfer_ownership: %{new_owner_email: context.second_user_email}})

        {:ok, context}
      end

      given_ "the new owner logs in and navigates to account settings", context do
        {:ok, login_view, _html} = live(build_conn(), "/users/log-in")

        login_form =
          form(login_view, "#login_form_password", user: %{
            email: context.second_user_email,
            password: context.second_user_password,
            remember_me: true
          })

        logged_in_conn = submit_form(login_form, build_conn())
        new_owner_conn = recycle(logged_in_conn)
        {:ok, view, _html} = live(new_owner_conn, "/accounts/settings")
        {:ok, Map.put(context, :new_owner_view, view)}
      end

      then_ "the new owner can see the delete account section", context do
        assert has_element?(context.new_owner_view, "[data-role='delete-account']")
        :ok
      end
    end
  end
end
