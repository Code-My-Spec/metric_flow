defmodule MetricFlowSpex.Criterion73IfAccountHasOriginatorRelationshipForWhiteLabelOriginatorStatusCanOptionallyTransferTooSpex do
  @moduledoc """
  Story 10 — Transfer Account Ownership
  Criterion 73 — If the account has an originator relationship for white-label,
  originator status can optionally transfer too.
  """

  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest

  import MetricFlowSpex.SharedGivens

  spex "If account has originator relationship for white-label, originator status can optionally transfer too",
       criterion: 73 do
    scenario "the owner's agency account originated a client account" do
      given_ :agency_owner_logged_in
      given_ :agency_member_registered

      given_ "the agency account is the originator for a client account", context do
        client = MetricFlowSpex.Fixtures.client_account_fixture("Originated Client")
        :ok = MetricFlowSpex.Fixtures.grant_client_account_access(context.owner_email, client.id, :admin, true)
        {:ok, context}
      end

      when_ "the owner opens the transfer ownership section", context do
        account_id = MetricFlowSpex.Fixtures.personal_account_id(context.owner_email)
        {:ok, view, _html} = live(context.owner_conn, "/app/accounts/settings?account_id=#{account_id}")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "the wizard offers to also transfer originator status", context do
        assert has_element?(context.view, "[data-role='transfer-originator-checkbox']")
        {:ok, context}
      end
    end
  end
end
