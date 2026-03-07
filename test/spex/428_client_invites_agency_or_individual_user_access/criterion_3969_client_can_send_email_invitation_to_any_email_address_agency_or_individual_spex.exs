defmodule MetricFlowSpex.ClientCanSendEmailInvitationToAnyEmailAddressSpex do
  use SexySpex
  use MetricFlowTest.ConnCase
  import Phoenix.LiveViewTest

  import_givens MetricFlowSpex.SharedGivens

  spex "Client can send email invitation to any email address (agency or individual)" do
    scenario "owner sends invitation to an external email address not yet in the system" do
      given_ :user_logged_in_as_owner

      given_ "the owner is on the members page", context do
        {:ok, view, _html} = live(context.owner_conn, "/accounts/invitations")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "the owner submits the invite form with an external email address", context do
        context.view
        |> form("#invite_member_form", invitation: %{
          email: "agency@externalfirm.com",
          role: "read_only"
        })
        |> render_submit()

        {:ok, context}
      end

      then_ "a success message is displayed confirming the invitation was sent", context do
        assert render(context.view) =~ "Invitation sent"
        :ok
      end
    end

    scenario "owner sends invitation to an individual user email address" do
      given_ :user_logged_in_as_owner
      given_ :second_user_registered

      given_ "the owner is on the members page", context do
        {:ok, view, _html} = live(context.owner_conn, "/accounts/invitations")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "the owner submits the invite form with an individual user's email", context do
        context.view
        |> form("#invite_member_form", invitation: %{
          email: context.second_user_email,
          role: "read_only"
        })
        |> render_submit()

        {:ok, context}
      end

      then_ "the invited user appears in the members list or a success message is shown", context do
        html = render(context.view)
        assert html =~ context.second_user_email or html =~ "Invitation sent"
        :ok
      end
    end

    scenario "owner sees invitation form on members page" do
      given_ :user_logged_in_as_owner

      given_ "the owner is on the members page", context do
        {:ok, view, _html} = live(context.owner_conn, "/accounts/invitations")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "the invite member form is displayed for entering any email address", context do
        assert has_element?(context.view, "#invite_member_form")
        assert has_element?(context.view, "input[name='invitation[email]']")
        :ok
      end
    end
  end
end
