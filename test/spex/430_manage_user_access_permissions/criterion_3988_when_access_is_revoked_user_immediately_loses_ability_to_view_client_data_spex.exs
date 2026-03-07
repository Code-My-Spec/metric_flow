defmodule MetricFlowSpex.WhenAccessIsRevokedUserImmediatelyLosesAbilityToViewClientDataSpex do
  use SexySpex
  use MetricFlowTest.ConnCase
  import Phoenix.LiveViewTest

  import_givens MetricFlowSpex.SharedGivens

  spex "When access is revoked, user immediately loses ability to view client data" do
    scenario "removed member can no longer access the account members page" do
      given_ :user_logged_in_as_owner
      given_ :second_user_registered

      given_ "the owner invites the second user to their account", context do
        {:ok, view, _html} = live(context.owner_conn, "/accounts/members")

        view
        |> form("#invite_member_form", invitation: %{
          email: context.second_user_email,
          role: "member"
        })
        |> render_submit()

        {:ok, Map.put(context, :members_view, view)}
      end

      given_ "the second user logs in and can access the members page", context do
        login_conn = build_conn()
        {:ok, login_view, _html} = live(login_conn, "/users/log-in")

        login_form =
          form(login_view, "#login_form_password", user: %{
            email: context.second_user_email,
            password: "SecurePassword123!",
            remember_me: true
          })

        logged_in_conn = submit_form(login_form, login_conn)
        member_conn = recycle(logged_in_conn)

        {:ok, Map.put(context, :member_conn, member_conn)}
      end

      when_ "the owner removes the second user from the account", context do
        html = render(context.members_view)
        [member_row | _] =
          html
          |> Floki.parse_document!()
          |> Floki.find("[data-role='member-row'][data-user-id]")
          |> Enum.reject(fn row ->
            Floki.text(row) =~ context.owner_email
          end)

        user_id =
          member_row
          |> Floki.attribute("data-user-id")
          |> List.first()

        context.members_view
        |> element("[data-role='remove-member'][data-user-email='#{context.second_user_email}']")
        |> render_click()

        {:ok, Map.put(context, :removed_user_id, user_id)}
      end

      then_ "the removed member is no longer in the members list", context do
        html = render(context.members_view)
        refute html =~ context.second_user_email
        :ok
      end

      then_ "the removed member cannot access the shared account data", context do
        result = live(context.member_conn, "/accounts/members")

        case result do
          {:error, {:redirect, %{to: redirect_path}}} ->
            assert redirect_path in ["/users/log-in", "/accounts", "/"]

          {:ok, view, _html} ->
            # The user still has their own account, so the page loads.
            # Verify they can no longer see the shared account's data (the owner's email).
            html = render(view)
            refute html =~ context.owner_email
        end

        :ok
      end
    end

    scenario "access revocation takes effect immediately without requiring re-login" do
      given_ :user_logged_in_as_owner
      given_ :second_user_registered

      given_ "the owner invites the second user to their account", context do
        {:ok, view, _html} = live(context.owner_conn, "/accounts/members")

        view
        |> form("#invite_member_form", invitation: %{
          email: context.second_user_email,
          role: "member"
        })
        |> render_submit()

        {:ok, Map.put(context, :members_view, view)}
      end

      given_ "the second user is logged in", context do
        login_conn = build_conn()
        {:ok, login_view, _html} = live(login_conn, "/users/log-in")

        login_form =
          form(login_view, "#login_form_password", user: %{
            email: context.second_user_email,
            password: "SecurePassword123!",
            remember_me: true
          })

        logged_in_conn = submit_form(login_form, login_conn)
        member_conn = recycle(logged_in_conn)

        {:ok, Map.put(context, :member_conn, member_conn)}
      end

      when_ "the owner immediately removes the second user without any delay", context do
        context.members_view
        |> element("[data-role='remove-member'][data-user-email='#{context.second_user_email}']")
        |> render_click()

        {:ok, context}
      end

      then_ "the owner sees a confirmation that the member was removed", context do
        assert render(context.members_view) =~ "Member removed"
        :ok
      end

      then_ "the second user can no longer see the shared account data on their next request", context do
        result = live(context.member_conn, "/accounts/members")

        case result do
          {:error, {:redirect, _}} ->
            :ok

          {:ok, view, _html} ->
            # The user still has their own account, so the page loads.
            # Verify they can no longer see the shared account's data (the owner's email).
            html = render(view)
            refute html =~ context.owner_email
        end

        :ok
      end
    end
  end
end
