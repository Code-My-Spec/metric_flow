defmodule MetricFlowSpex.ClientDowngradesAUsersAccessLevelSpex do
  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest

  import MetricFlowSpex.SharedGivens

  spex "Client downgrades a user's access level", criterion: 555 do
    scenario "Jordan downgrades an admin teammate to read-only" do
      given_ :user_logged_in_as_owner
      given_ :second_user_registered

      given_ "a teammate currently has admin access", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/accounts/members")

        view
        |> form("#invite_member_form", invitation: %{
          email: context.second_user_email,
          role: "admin"
        })
        |> render_submit()

        {:ok, Map.put(context, :view, view)}
      end

      when_ "Jordan downgrades them to read-only", context do
        context.view
        |> element("[data-role='change-role'][data-user-email='#{context.second_user_email}']")
        |> render_click(%{"role" => "read_only"})

        {:ok, context}
      end

      then_ "their access level is updated", context do
        html = render(context.view)
        assert html =~ "Role updated"
        assert html =~ context.second_user_email
        assert html =~ "read_only"
        {:ok, context}
      end
    end
  end
end
