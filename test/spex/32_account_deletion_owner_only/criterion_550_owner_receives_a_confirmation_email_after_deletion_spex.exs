defmodule MetricFlowSpex.OwnerReceivesAConfirmationEmailAfterDeletionSpex do
  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest
  import Swoosh.TestAssertions

  import MetricFlowSpex.SharedGivens

  spex "Owner receives a confirmation email after deletion", criterion: 550 do
    scenario "owner deletes his account and receives a confirmation email" do
      given_ :user_logged_in_as_owner

      given_ "Alex has just deleted his account", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/accounts/settings")

        view
        |> form("#delete-account-form", delete_confirmation: %{
          account_name: "Owner Account",
          password: context.owner_password
        })
        |> render_submit()

        {:ok, context}
      end

      then_ "Alex receives a confirmation email", context do
        assert_email_sent(fn email ->
          Enum.any?(email.to, fn {_name, addr} -> addr == context.owner_email end)
        end)

        {:ok, context}
      end
    end
  end
end
