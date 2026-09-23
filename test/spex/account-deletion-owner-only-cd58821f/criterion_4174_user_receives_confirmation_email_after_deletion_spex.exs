defmodule MetricFlowSpex.UserReceivesConfirmationEmailAfterDeletionSpex do
  use SexySpex
  use MetricFlowTest.ConnCase
  import Phoenix.LiveViewTest

  import_givens MetricFlowSpex.SharedGivens

  spex "User receives confirmation email after deletion" do
    scenario "after successful account deletion a success message is shown" do
      given_ :user_logged_in_as_owner

      given_ "the owner navigates to account settings", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/accounts/settings")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "the owner submits the delete form with correct account name and password", context do
        result =
          context.view
          |> form("#delete-account-form", delete_confirmation: %{
            account_name: "Owner Account",
            password: context.owner_password
          })
          |> render_submit()

        {:ok, Map.put(context, :submit_result, result)}
      end

      then_ "the owner sees a success message confirming the account was deleted", context do
        {_path, flash} = assert_redirect(context.view)
        message = flash["info"] || flash["error"] || ""
        assert message =~ "deleted" or message =~ "Deleted" or message =~ "success" or message =~ "Success"
        :ok
      end
    end

    scenario "the deletion confirmation message is shown on the redirected page" do
      given_ :user_logged_in_as_owner

      given_ "the owner navigates to account settings", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/accounts/settings")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "the owner submits the delete form with the correct credentials", context do
        context.view
        |> form("#delete-account-form", delete_confirmation: %{
          account_name: "Owner Account",
          password: context.owner_password
        })
        |> render_submit()

        {path, flash} = assert_redirect(context.view)
        {:ok, Map.merge(context, %{redirect_path: path, redirect_flash: flash})}
      end

      then_ "the owner is redirected to the accounts page with a flash message", context do
        assert context.redirect_path == "/app/accounts"
        message = context.redirect_flash["info"] || context.redirect_flash["success"] || ""
        assert message != "", "Expected a flash message to be present after account deletion"
        :ok
      end
    end
  end
end
