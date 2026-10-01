defmodule MetricFlowSpex.Criterion904WhiteLabelOriginatorStatusOptionallyTransfersWithOwnershipSpex do
  @moduledoc """
  Story 10 — Transfer Account Ownership
  Criterion 904 — White-label originator status optionally transfers with ownership.

  Originator status is recorded on the agency-account-to-client grant
  (MetricFlow.Agencies), not on the owning user, so "transfers with
  ownership" is read here as: the originated relationship survives an
  ownership transfer of the agency account when the owner opts in via
  the transfer wizard's originator checkbox.
  """

  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest
  import Swoosh.TestAssertions

  import MetricFlowSpex.SharedGivens

  spex "White-label originator status optionally transfers with ownership", criterion: 904 do
    scenario "the owner transfers ownership and opts to carry over originator status" do
      given_ :agency_owner_logged_in
      given_ :agency_member_registered

      given_ "the agency account is the originator for a client account", context do
        client = MetricFlowSpex.Fixtures.client_account_fixture("Originated Client")
        :ok = MetricFlowSpex.Fixtures.grant_client_account_access(context.owner_email, client.id, :admin, true)

        # client_account_fixture/1 creates its owning user via user_fixture/1,
        # which delivers a real login-instructions email as a side effect of
        # capturing its token -- drain that now, before the transfer step
        # sends its own email, since assert_email_sent takes whichever
        # {:email, _} arrives first.
        drain_mailbox()

        {:ok, context}
      end

      given_ "the owner transfers ownership and opts to transfer originator status", context do
        member = MetricFlowTest.UsersFixtures.get_user_by_email(context.member_email)
        account_id = MetricFlowSpex.Fixtures.personal_account_id(context.owner_email)
        {:ok, view, _html} = live(context.owner_conn, "/app/accounts/settings?account_id=#{account_id}")

        view
        |> form("#transfer-ownership-form", %{
          "transfer_target" => "existing",
          "user_id" => to_string(member.id),
          "transfer_originator" => "true"
        })
        |> render_submit()

        token =
          assert_email_sent(fn email ->
            [_, t] = Regex.run(~r|/account_transfers/([^\s/]+)|, email.text_body)
            t
          end)

        {:ok, Map.put(context, :transfer_token, token)}
      end

      when_ "the new owner confirms the transfer", context do
        {:ok, view, _html} = live(context.member_conn, "/account_transfers/#{context.transfer_token}")

        view
        |> element("[data-role='accept-transfer-btn']")
        |> render_click()

        {:ok, context}
      end

      then_ "originator status still accompanies the account under the new owner", context do
        {:ok, clients_view, _html} = live(context.member_conn, "/app/agency/clients")
        assert render(clients_view) =~ "Originated"
        {:ok, context}
      end
    end
  end
end
