defmodule MetricFlowSpex.OriginatorWhoIsNoLongerOwnerCannotDeleteTheAccountSpex do
  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest
  import Swoosh.TestAssertions

  import MetricFlowSpex.SharedGivens

  spex "Originator who is no longer owner cannot delete the account", criterion: 542 do
    scenario "originator whose ownership has been transferred cannot delete the account" do
      given_ :user_logged_in_as_owner
      given_ :second_user_registered

      given_ "the second user has been invited as admin", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/accounts/members")

        view
        |> form("#invite_member_form", invitation: %{
          email: context.second_user_email,
          role: "admin"
        })
        |> render_submit()

        {:ok, context}
      end

      given_ "ownership has since transferred to someone else", context do
        member = MetricFlowTest.UsersFixtures.get_user_by_email(context.second_user_email)
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
              email: context.second_user_email,
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

        {:ok, context}
      end

      when_ "the former owner attempts to delete the account", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/accounts/settings")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "the action is blocked because the former owner is not the current owner", context do
        refute has_element?(context.view, "[data-role='delete-account']")
        {:ok, context}
      end
    end
  end
end
