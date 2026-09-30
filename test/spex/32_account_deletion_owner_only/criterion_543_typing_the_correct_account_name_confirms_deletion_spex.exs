defmodule MetricFlowSpex.TypingTheCorrectAccountNameConfirmsDeletionSpex do
  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest

  import MetricFlowSpex.SharedGivens

  spex "Typing the correct account name confirms deletion", criterion: 543 do
    scenario "owner starts the delete flow and types the account's exact name to confirm" do
      given_ :user_logged_in_as_owner

      given_ "Alex is the account owner and starts the delete flow", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/accounts/settings")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "Alex types the account's exact name to confirm", context do
        result =
          context.view
          |> form("#delete-account-form", delete_confirmation: %{
            account_name: "Owner Account",
            password: context.owner_password
          })
          |> render_submit()

        {:ok, Map.put(context, :submit_result, result)}
      end

      then_ "the confirmation step passes", context do
        assert_redirect(context.view, "/app/accounts")
        {:ok, context}
      end
    end
  end
end
