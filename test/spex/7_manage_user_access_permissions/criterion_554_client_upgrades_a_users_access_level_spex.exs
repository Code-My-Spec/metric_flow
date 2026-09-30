defmodule MetricFlowSpex.ClientUpgradesAUsersAccessLevelSpex do
  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest

  import MetricFlowSpex.SharedGivens

  spex "Client upgrades a user's access level", criterion: 554 do
    scenario "Jordan upgrades a read-only teammate to account manager" do
      given_ :user_logged_in_as_owner
      given_ :second_user_registered

      given_ "a teammate currently has read-only access", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/accounts/members")

        view
        |> form("#invite_member_form", invitation: %{
          email: context.second_user_email,
          role: "read_only"
        })
        |> render_submit()

        {:ok, Map.put(context, :view, view)}
      end

      when_ "Jordan upgrades them to account manager", context do
        context.view
        |> element("[data-role='change-role'][data-user-email='#{context.second_user_email}']")
        |> render_click(%{"role" => "account_manager"})

        {:ok, context}
      end

      then_ "their access level is updated", context do
        html = render(context.view)
        assert html =~ "Role updated"
        assert html =~ context.second_user_email
        assert html =~ "account_manager"
        {:ok, context}
      end
    end
  end
end
