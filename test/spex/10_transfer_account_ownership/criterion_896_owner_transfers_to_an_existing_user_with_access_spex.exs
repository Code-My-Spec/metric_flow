defmodule MetricFlowSpex.Criterion896OwnerTransfersToAnExistingUserWithAccessSpex do
  @moduledoc """
  Story 10 — Transfer Account Ownership
  Criterion 896 — The owner transfers ownership to an existing user with access.
  """

  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest

  import MetricFlowSpex.SharedGivens

  spex "Owner transfers to an existing user with access", criterion: 896 do
    scenario "the owner selects a member with existing access as the new owner" do
      given_ :user_logged_in_as_owner
      given_ :owner_has_member_with_access

      when_ "the owner selects them as the new owner", context do
        member = MetricFlowTest.UsersFixtures.get_user_by_email(context.member_email)
        {:ok, view, _html} = live(context.owner_conn, "/app/accounts/settings")

        view
        |> form("#transfer-ownership-form", %{
          "transfer_target" => "existing",
          "user_id" => to_string(member.id)
        })
        |> render_submit()

        {:ok, Map.put(context, :view, view)}
      end

      then_ "a transfer is initiated to that existing user", context do
        assert has_element?(context.view, "[data-role='transfer-pending-banner']")
        assert render(context.view) =~ context.member_email
        {:ok, context}
      end
    end
  end
end
