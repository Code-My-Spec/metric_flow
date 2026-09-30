defmodule MetricFlowSpex.CorrectPasswordReEntryAllowsDeletionToProceedSpex do
  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest

  import MetricFlowSpex.SharedGivens

  spex "Correct password re-entry allows deletion to proceed", criterion: 545 do
    scenario "owner confirms the account name and re-enters the correct password" do
      given_ :user_logged_in_as_owner

      given_ "Alex has confirmed the account name", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/accounts/settings")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "Alex re-enters his correct password", context do
        result =
          context.view
          |> form("#delete-account-form", delete_confirmation: %{
            account_name: "Owner Account",
            password: context.owner_password
          })
          |> render_submit()

        {:ok, Map.put(context, :submit_result, result)}
      end

      then_ "deletion proceeds", context do
        assert_redirect(context.view, "/app/accounts")
        {:ok, context}
      end
    end
  end
end
