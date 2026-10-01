defmodule MetricFlowSpex.AccountOriginatorCannotDeleteAccountTheyOriginatedSpex do
  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest
  import Swoosh.TestAssertions

  import MetricFlowSpex.SharedGivens

  spex "Account originator cannot delete account they originated (only owner can)", criterion: 266 do
    scenario "originator who transferred ownership cannot see delete account section" do
      given_ :user_logged_in_as_owner
      given_ :second_user_registered

      given_ "the originator invites the second user as admin", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/accounts/members")

        view
        |> form("#invite_member_form", invitation: %{
          email: context.second_user_email,
          role: "admin"
        })
        |> render_submit()

        {:ok, context}
      end

      given_ "the originator transfers ownership to the second user and the second user confirms", context do
        {:ok, context} = complete_ownership_transfer(context, context.second_user_email)
        {:ok, context}
      end

      given_ "the originator navigates to account settings after the transfer", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/accounts/settings")
        {:ok, Map.put(context, :originator_view, view)}
      end

      then_ "the originator cannot see the delete account section", context do
        refute has_element?(context.originator_view, "[data-role='delete-account']")
        {:ok, context}
      end
    end

    scenario "new owner who received transferred ownership can see delete account section" do
      given_ :user_logged_in_as_owner
      given_ :second_user_registered

      given_ "the originator invites the second user as admin", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/accounts/members")

        view
        |> form("#invite_member_form", invitation: %{
          email: context.second_user_email,
          role: "admin"
        })
        |> render_submit()

        {:ok, context}
      end

      given_ "the originator transfers ownership to the second user and the second user confirms", context do
        {:ok, context} = complete_ownership_transfer(context, context.second_user_email)
        {:ok, context}
      end

      given_ "the new owner navigates to account settings", context do
        {:ok, view, _html} = live(context.new_owner_conn, "/app/accounts/settings")
        {:ok, Map.put(context, :new_owner_view, view)}
      end

      then_ "the new owner can see the delete account section", context do
        assert has_element?(context.new_owner_view, "[data-role='delete-account']")
        {:ok, context}
      end
    end
  end

  # Submits the real transfer-ownership form, extracts the confirmation
  # token from the email it sends, logs in as the recipient, and accepts --
  # criteria 68/898 require this full round trip before anything transfers.
  defp complete_ownership_transfer(context, target_email) do
    member = MetricFlowTest.UsersFixtures.get_user_by_email(target_email)
    {:ok, view, _html} = live(context.owner_conn, "/app/accounts/settings")

    view
    |> form("#transfer-ownership-form", %{
      "transfer_target" => "existing",
      "user_id" => to_string(member.id)
    })
    |> render_submit()

    token =
      assert_email_sent(fn email ->
        [_, t] = Regex.run(~r|/account_transfers/([^\s/]+)|, email.text_body)
        t
      end)

    {:ok, login_view, _html} = live(build_conn(), "/users/log-in")

    login_form =
      form(login_view, "#login_form_password",
        user: %{
          email: target_email,
          password: context.second_user_password,
          remember_me: true
        }
      )

    logged_in_conn = submit_form(login_form, build_conn())
    new_owner_conn = recycle(logged_in_conn)

    {:ok, accept_view, _html} = live(new_owner_conn, "/account_transfers/#{token}")

    accept_view
    |> element("[data-role='accept-transfer-btn']")
    |> render_click()

    {:ok, Map.put(context, :new_owner_conn, new_owner_conn)}
  end
end
