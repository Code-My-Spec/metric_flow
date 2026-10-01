defmodule MetricFlowSpex.SelectingMultipleIncomeAccountsSumsTheirDebitsAndCreditsSpex do
  @moduledoc """
  Criterion 916 — selecting more than one QuickBooks income account to track
  should result in the system tracking all of them. Summing debits and
  credits across the selected accounts happens downstream during sync; this
  spec covers the connect flow's share of the contract, that a user can in
  fact select and persist more than one tracked income account.
  """

  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest

  import MetricFlowSpex.SharedGivens

  spex "Selecting multiple income accounts sums their debits and credits", criterion: 916 do
    scenario "a user selects more than one income account and the system tracks all of them" do
      given_ :owner_with_quickbooks_integration

      given_ "the user is on the QuickBooks account selection page", context do
        {:ok, view, _html} =
          live(context.owner_conn, "/app/integrations/connect/quickbooks/accounts")

        {:ok, Map.put(context, :view, view)}
      end

      when_ "the user selects more than one income account to track", context do
        result =
          context.view
          |> element("[data-role='account-selection']")
          |> render_submit(%{"income_account_ids" => ["1001", "1002"]})

        {:ok, Map.put(context, :save_result, result)}
      end

      then_ "the system tracks all of the selected income accounts", context do
        {:ok, accounts_view, _html} =
          live(context.owner_conn, "/app/integrations/connect/quickbooks/accounts")

        assert has_element?(accounts_view, "[data-role='account-checkbox'][value='1001']") and
                 has_element?(accounts_view, "[data-role='account-checkbox'][value='1002']")

        {:ok, context}
      end
    end
  end
end
