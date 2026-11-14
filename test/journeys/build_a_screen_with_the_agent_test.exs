defmodule MetricFlowWeb.Journeys.BuildAScreenWithTheAgentTest do
  @moduledoc """
  Journey 6 from `.code_my_spec/qa/journey_plan.md` (Story 74): a user
  describes a dashboard in chat and the agent builds it as a draft.

  Fails at step 2 -- there is no chat affordance on `/app/dashboards/new`
  yet. Tracked in `.code_my_spec/qa/journey_result.md` Journey 6 as a real,
  unbuilt feature (no draft/version fields on `Dashboard`, no multi-widget
  chat authoring), not a UI defect to patch in this test.
  """

  use MetricFlowTest.ConnCase, async: true

  import Phoenix.LiveViewTest
  import MetricFlowTest.UsersFixtures

  alias MetricFlow.Accounts.Account
  alias MetricFlow.Accounts.AccountMember
  alias MetricFlow.Repo

  defp unique_slug, do: "account-#{System.unique_integer([:positive])}"

  defp insert_account!(user, attrs \\ %{}) do
    defaults = %{
      name: "QA Test Account",
      slug: unique_slug(),
      type: "client",
      originator_user_id: user.id
    }

    %Account{}
    |> Account.creation_changeset(Map.merge(defaults, attrs))
    |> Repo.insert!()
  end

  defp insert_member!(account, user, role) do
    %AccountMember{}
    |> AccountMember.changeset(%{account_id: account.id, user_id: user.id, role: role})
    |> Repo.insert!()
  end

  test "describing a dashboard in chat builds it as a draft", %{conn: conn} do
    user = user_fixture()
    account = insert_account!(user)
    insert_member!(account, user, :owner)

    conn = log_in_user(conn, user)

    # Step 2: a chat affordance to describe the dashboard in natural language
    {:ok, view, _html} = live(conn, ~p"/app/dashboards/new")

    assert has_element?(view, "[data-role='dashboard-chat-input']"),
           "Story 74 is not built: /app/dashboards/new has no chat affordance " <>
             "to describe a dashboard (see journey_result.md Journey 6)"

    # Steps 3-5 (unreached until the chat affordance above exists): submit
    # "a headline stat, a spend-over-time line chart and a table of
    # campaigns", assert a draft Dashboard is created with those widgets,
    # then reopen it via "Edit with agent" and confirm chat history and a
    # restorable version list persist with it.
  end
end
