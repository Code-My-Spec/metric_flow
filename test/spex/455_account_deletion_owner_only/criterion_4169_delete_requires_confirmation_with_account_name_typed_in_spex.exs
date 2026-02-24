defmodule MetricFlowSpex.DeleteRequiresConfirmationWithAccountNameTypedInSpex do
  use SexySpex
  use MetricFlowTest.ConnCase
  import Phoenix.LiveViewTest

  import_givens MetricFlowSpex.SharedGivens

  spex "Delete requires confirmation with account name typed in" do
    scenario "deletion is rejected when typed account name does not match" do
      given_ :user_logged_in_as_owner

      given_ "the owner navigates to account settings", context do
        {:ok, view, _html} = live(context.owner_conn, "/accounts/settings")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "the owner submits the delete form with the wrong account name", context do
        context.view
        |> form("#delete-account-form", delete_confirmation: %{
          account_name: "Wrong Name",
          password: context.owner_password
        })
        |> render_submit()

        {:ok, context}
      end

      then_ "the owner sees an error message about the account name not matching", context do
        assert render(context.view) =~ "Account name does not match"
        :ok
      end
    end

    scenario "deletion succeeds when correct account name and password are entered" do
      given_ :user_logged_in_as_owner

      given_ "the owner navigates to account settings", context do
        {:ok, view, _html} = live(context.owner_conn, "/accounts/settings")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "the owner submits the delete form with the correct account name and password", context do
        result =
          context.view
          |> form("#delete-account-form", delete_confirmation: %{
            account_name: "Owner Account",
            password: context.owner_password
          })
          |> render_submit()

        {:ok, Map.put(context, :submit_result, result)}
      end

      then_ "the owner is redirected to the accounts list", context do
        assert_redirect(context.view, "/accounts")
        :ok
      end
    end
  end
end
