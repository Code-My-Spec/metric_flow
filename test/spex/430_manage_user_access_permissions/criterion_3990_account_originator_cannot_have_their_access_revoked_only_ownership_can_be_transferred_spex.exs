defmodule MetricFlowSpex.AccountOriginatorCannotHaveTheirAccessRevokedOnlyOwnershipCanBeTransferredSpex do
  use SexySpex
  use MetricFlowTest.ConnCase
  import Phoenix.LiveViewTest

  import_givens MetricFlowSpex.SharedGivens

  spex "Account originator cannot have their access revoked, only ownership can be transferred" do
    scenario "the sole account owner has no remove button on their own member row" do
      given_ :user_logged_in_as_owner

      given_ "the owner navigates to the account members page", context do
        {:ok, view, _html} = live(context.owner_conn, "/accounts/members")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "the owner's member row is present", context do
        assert has_element?(context.view, "[data-role='member']")
        :ok
      end

      then_ "there is no remove button shown for the sole owner", context do
        html = render(context.view)
        parsed = Floki.parse_document!(html)

        remove_buttons = Floki.find(parsed, "[data-role='remove-member']")

        owner_remove_button =
          Enum.find(remove_buttons, fn btn ->
            Floki.attribute(btn, "data-user-email") == [context.owner_email]
          end)

        assert is_nil(owner_remove_button),
               "Expected no remove button for the sole account owner, but one was found"

        :ok
      end
    end

    scenario "the remove button appears for another member but not for the sole owner" do
      given_ :user_logged_in_as_owner
      given_ :second_user_registered

      given_ "the owner invites the second user as a member", context do
        {:ok, view, _html} = live(context.owner_conn, "/accounts/members")

        view
        |> form("#invite_member_form", invitation: %{
          email: context.second_user_email,
          role: "member"
        })
        |> render_submit()

        {:ok, Map.put(context, :view, view)}
      end

      then_ "a remove button exists for the invited member", context do
        assert has_element?(
          context.view,
          "[data-role='remove-member'][data-user-email='#{context.second_user_email}']"
        )

        :ok
      end

      then_ "no remove button exists for the sole account owner", context do
        refute has_element?(
          context.view,
          "[data-role='remove-member'][data-user-email='#{context.owner_email}']"
        )

        :ok
      end
    end

    scenario "ownership can be transferred to another member via account settings" do
      given_ :user_logged_in_as_owner
      given_ :second_user_registered

      given_ "the owner invites the second user as a member before transfer", context do
        {:ok, members_view, _html} = live(context.owner_conn, "/accounts/members")

        members_view
        |> form("#invite_member_form", invitation: %{
          email: context.second_user_email,
          role: "member"
        })
        |> render_submit()

        {:ok, Map.put(context, :members_view, members_view)}
      end

      given_ "the owner navigates to account settings", context do
        {:ok, settings_view, _html} = live(context.owner_conn, "/accounts/settings")
        {:ok, Map.put(context, :settings_view, settings_view)}
      end

      then_ "the transfer ownership form is visible", context do
        assert has_element?(context.settings_view, "[data-role='transfer-ownership']")
        :ok
      end

      when_ "the owner submits the transfer ownership form", context do
        html =
          context.settings_view
          |> form("[data-role='transfer-ownership']")
          |> render_submit()

        {:ok, Map.put(context, :transfer_result_html, html)}
      end

      then_ "ownership is transferred successfully", context do
        assert render(context.settings_view) =~ "Ownership transferred successfully"
        :ok
      end
    end
  end
end
