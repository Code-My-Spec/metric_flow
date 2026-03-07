defmodule MetricFlowSpex.ClientCanInviteMultipleAgenciesOrUsersWithDifferentAccessLevelsSpex do
  use SexySpex
  use MetricFlowTest.ConnCase
  import Phoenix.LiveViewTest

  import_givens MetricFlowSpex.SharedGivens

  spex "Client can invite multiple agencies or users with different access levels" do
    scenario "owner can send a second invitation to a different email after the first" do
      given_ :user_logged_in_as_owner

      given_ "the owner is on the members page", context do
        {:ok, view, _html} = live(context.owner_conn, "/accounts/invitations")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "the owner sends a first invitation with read_only access", context do
        context.view
        |> form("#invite_member_form", invitation: %{
          email: "first@agency.com",
          role: "read_only"
        })
        |> render_submit()

        {:ok, context}
      end

      when_ "the owner sends a second invitation with admin access to a different email", context do
        context.view
        |> form("#invite_member_form", invitation: %{
          email: "second@agency.com",
          role: "admin"
        })
        |> render_submit()

        {:ok, context}
      end

      then_ "both invitations are visible in the pending invitations list", context do
        html = render(context.view)
        assert html =~ "first@agency.com"
        assert html =~ "second@agency.com"
        :ok
      end
    end

    scenario "each pending invitation in the list shows its own assigned access level" do
      given_ :user_logged_in_as_owner

      given_ "the owner is on the members page", context do
        {:ok, view, _html} = live(context.owner_conn, "/accounts/invitations")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "the owner sends one invitation with read_only and one with account_manager access", context do
        context.view
        |> form("#invite_member_form", invitation: %{
          email: "readonly@agency.com",
          role: "read_only"
        })
        |> render_submit()

        context.view
        |> form("#invite_member_form", invitation: %{
          email: "manager@agency.com",
          role: "account_manager"
        })
        |> render_submit()

        {:ok, context}
      end

      then_ "the pending invitations list shows read_only for the first invitee", context do
        assert render(context.view) =~ "read_only"
        :ok
      end

      then_ "the pending invitations list shows account_manager for the second invitee", context do
        assert render(context.view) =~ "account_manager"
        :ok
      end
    end

    scenario "invite form is still available after sending a successful invitation" do
      given_ :user_logged_in_as_owner
      given_ :second_user_registered

      given_ "the owner is on the members page", context do
        {:ok, view, _html} = live(context.owner_conn, "/accounts/invitations")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "the owner sends an invitation to the second user", context do
        context.view
        |> form("#invite_member_form", invitation: %{
          email: context.second_user_email,
          role: "read_only"
        })
        |> render_submit()

        {:ok, context}
      end

      then_ "the invite form is still present and ready for another invitation", context do
        assert has_element?(context.view, "#invite_member_form")
        assert has_element?(context.view, "input[name='invitation[email]']")
        :ok
      end
    end

    scenario "each invitation sent to different recipients triggers a separate email delivery" do
      given_ :user_logged_in_as_owner
      import Swoosh.TestAssertions

      given_ "the owner is on the members page", context do
        {:ok, view, _html} = live(context.owner_conn, "/accounts/invitations")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "the owner sends invitations to two different email addresses", context do
        context.view
        |> form("#invite_member_form", invitation: %{
          email: "alpha@agency.com",
          role: "read_only"
        })
        |> render_submit()

        context.view
        |> form("#invite_member_form", invitation: %{
          email: "beta@agency.com",
          role: "admin"
        })
        |> render_submit()

        {:ok, context}
      end

      then_ "an invitation email was sent to the first recipient", context do
        assert_email_sent(to: "alpha@agency.com")
        :ok
      end

      then_ "an invitation email was sent to the second recipient", context do
        assert_email_sent(to: "beta@agency.com")
        :ok
      end
    end
  end
end
