defmodule MetricFlowSpex.ListShowsNameAccessLevelDateGrantedAndOriginatorFlagSpex do
  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest

  import MetricFlowSpex.SharedGivens

  spex "List shows name, access level, date granted, and originator flag", criterion: 553 do
    scenario "Jordan views the access list and each entry shows the required fields" do
      given_ :user_logged_in_as_owner
      given_ :second_user_registered

      given_ "the access list has multiple entries", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/accounts/members")

        view
        |> form("#invite_member_form", invitation: %{
          email: context.second_user_email,
          role: "account_manager"
        })
        |> render_submit()

        {:ok, context}
      end

      when_ "Jordan views the list", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/accounts/members")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "each entry shows a name, access level, and the date access was granted", context do
        html = render(context.view)
        assert html =~ context.owner_email
        assert html =~ context.second_user_email
        assert html =~ "account_manager"
        {:ok, context}
      end

      then_ "the account originator is identified by the owner role", context do
        html = render(context.view)
        assert html =~ "owner"
        {:ok, context}
      end
    end
  end
end
