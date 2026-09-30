defmodule MetricFlowSpex.IncorrectPasswordBlocksDeletionSpex do
  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest

  import MetricFlowSpex.SharedGivens

  spex "Incorrect password blocks deletion", criterion: 546 do
    scenario "owner confirms the account name but enters an incorrect password" do
      given_ :user_logged_in_as_owner

      given_ "Alex has confirmed the account name", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/accounts/settings")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "Alex enters an incorrect password", context do
        context.view
        |> form("#delete-account-form", delete_confirmation: %{
          account_name: "Owner Account",
          password: "TotallyWrongPassword123!"
        })
        |> render_submit()

        {:ok, context}
      end

      then_ "deletion is blocked", context do
        assert render(context.view) =~ "Incorrect password"

        {:ok, settings_view, _html} = live(context.owner_conn, "/app/accounts/settings")
        assert has_element?(settings_view, "[data-role='delete-account']")
        {:ok, context}
      end
    end
  end
end
