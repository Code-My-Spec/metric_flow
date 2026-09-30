defmodule MetricFlowSpex.OriginatorWhoIsNoLongerOwnerCannotDeleteTheAccountSpex do
  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest

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
        {:ok, view, _html} = live(context.owner_conn, "/app/accounts/settings")

        view
        |> element("[data-role='transfer-ownership']")
        |> render_submit(%{transfer_ownership: %{new_owner_email: context.second_user_email}})

        {:ok, context}
      end

      when_ "Alex attempts to delete the account", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/accounts/settings")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "the action is blocked because Alex is not the current owner", context do
        refute has_element?(context.view, "[data-role='delete-account']")
        {:ok, context}
      end
    end
  end
end
