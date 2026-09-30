defmodule MetricFlowSpex.PermissionChangesAreLoggedWithTimestampAndActorSpex do
  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest
  import ExUnit.CaptureLog

  import MetricFlowSpex.SharedGivens

  spex "Permission changes are logged with timestamp and actor", criterion: 558 do
    scenario "a role change is logged with a timestamp and the acting user" do
      given_ :user_logged_in_as_owner
      given_ :second_user_registered

      given_ "the owner invites the second user with read_only role", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/accounts/members")

        view
        |> form("#invite_member_form", invitation: %{
          email: context.second_user_email,
          role: "read_only"
        })
        |> render_submit()

        {:ok, Map.put(context, :view, view)}
      end

      when_ "Jordan modifies the second user's access level", context do
        Logger.configure(level: :info)

        log =
          capture_log(fn ->
            context.view
            |> element("[data-role='change-role'][data-user-email='#{context.second_user_email}']")
            |> render_click(%{"role" => "admin"})
          end)

        Logger.configure(level: :warning)

        {:ok, Map.put(context, :log, log)}
      end

      then_ "a log entry records the change, its timestamp, and that Jordan made it", context do
        assert context.log =~ "permission_change"
        assert context.log =~ context.owner_email
        assert context.log =~ "at="
        {:ok, context}
      end
    end
  end
end
