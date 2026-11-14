defmodule MetricFlowSpex.Story75.Criterion1072Spex do
  @moduledoc """
  Story 75 — Save, List and Reopen Dashboards
  Criterion 1072 — Only roles that may build can create, edit and delete
  dashboards; a read-only member is refused outright.
  """

  use MetricFlowSpex.Case, async: false

  import MetricFlowSpex.SharedGivens

  spex "A read-only member cannot start a dashboard", criterion: 1072 do
    scenario "opening /dashboards/new while scoped to a read-only account is refused" do
      given_(:user_logged_in_as_owner)
      given_(:owner_has_read_only_member)

      given_ "the member switches to the owner's account", context do
        {:ok, view, html} = live(context.read_only_conn, ~p"/app/accounts")

        [owner_account_id] =
          html
          |> Floki.parse_fragment!()
          |> Floki.find("[data-role='account-card']")
          |> Enum.filter(&(Floki.text(&1) =~ "Owner Account"))
          |> Floki.attribute("data-account-id")

        view
        |> element("[data-role='switch-account'][phx-value-account_id='#{owner_account_id}']")
        |> render_click()

        {:ok, context}
      end

      when_ "they open /dashboards/new", context do
        result = live(context.read_only_conn, ~p"/app/dashboards/new")
        {:ok, Map.put(context, :result, result)}
      end

      then_ "they are refused and no dashboard is created", context do
        assert {:error, {:redirect, %{to: "/app/dashboards"}}} = context.result

        {:ok, redirected_view, _html} = live(context.read_only_conn, ~p"/app/dashboards")
        assert has_element?(redirected_view, "[data-role='empty-user-dashboards']")
        {:ok, context}
      end
    end
  end
end
