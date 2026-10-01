defmodule MetricFlowSpex.Criterion897OwnerInvitesANewEmailAddressAsTheNewOwnerSpex do
  @moduledoc """
  Story 10 — Transfer Account Ownership
  Criterion 897 — The owner invites a new email address as the new owner.
  """

  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest
  import Swoosh.TestAssertions

  import MetricFlowSpex.SharedGivens

  spex "Owner invites a new email address as the new owner", criterion: 897 do
    scenario "the owner sends a transfer invitation to an email not yet on the account" do
      given_ :user_logged_in_as_owner

      given_ "an email address not yet associated with the account", context do
        email = "newowner#{System.unique_integer([:positive])}@example.com"
        {:ok, Map.put(context, :new_owner_email, email)}
      end

      when_ "the owner sends a transfer invitation to that email", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/accounts/settings")

        view
        |> form("#transfer-ownership-form", %{
          "transfer_target" => "invite",
          "invite_email" => context.new_owner_email
        })
        |> render_submit()

        {:ok, context}
      end

      then_ "a transfer invitation is sent to that new email", context do
        assert_email_sent(to: context.new_owner_email)
        {:ok, context}
      end
    end
  end
end
