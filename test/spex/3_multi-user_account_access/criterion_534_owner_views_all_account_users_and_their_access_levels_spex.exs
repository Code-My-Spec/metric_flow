defmodule MetricFlowSpex.OwnerViewsAllAccountUsersAndTheirAccessLevelsSpex do
  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest

  import MetricFlowSpex.SharedGivens

  spex "Owner views all account users and their access levels", criterion: 534 do
    scenario "Alex opens the members list and sees everyone with their current access level" do
      given_ :user_logged_in_as_owner
      given_ :second_user_registered

      given_ "the second user has been invited as account manager", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/accounts/members")

        view
        |> form("#invite_member_form", invitation: %{
          email: context.second_user_email,
          role: "account_manager"
        })
        |> render_submit()

        {:ok, context}
      end

      when_ "Alex opens the members list", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/accounts/members")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "Alex sees every user on the account with their current access level", context do
        html = render(context.view)

        assert html =~ context.owner_email
        assert html =~ "owner"
        assert html =~ context.second_user_email
        assert html =~ "account_manager"

        {:ok, context}
      end
    end
  end
end
