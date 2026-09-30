defmodule MetricFlowSpex.TypingTheWrongAccountNameBlocksDeletionSpex do
  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest

  import MetricFlowSpex.SharedGivens

  spex "Typing the wrong account name blocks deletion", criterion: 544 do
    scenario "owner starts the delete flow and types a name that doesn't match the account's name" do
      given_ :user_logged_in_as_owner

      given_ "Alex is the account owner and starts the delete flow", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/accounts/settings")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "Alex types a name that doesn't match the account's name", context do
        context.view
        |> form("#delete-account-form", delete_confirmation: %{
          account_name: "Not The Real Name",
          password: context.owner_password
        })
        |> render_submit()

        {:ok, context}
      end

      then_ "the confirmation step fails and the account is not deleted", context do
        assert render(context.view) =~ "Account name does not match"

        {:ok, settings_view, _html} = live(context.owner_conn, "/app/accounts/settings")
        assert has_element?(settings_view, "[data-role='delete-account']")
        {:ok, context}
      end
    end
  end
end
