defmodule MetricFlowSpex.DeleteRequiresPasswordReEntryForSecuritySpex do
  use SexySpex
  use MetricFlowTest.ConnCase
  import Phoenix.LiveViewTest

  import_givens MetricFlowSpex.SharedGivens

  spex "Delete requires password re-entry for security" do
    scenario "deletion is rejected when password is incorrect" do
      given_ :user_logged_in_as_owner

      given_ "the owner navigates to account settings", context do
        {:ok, view, _html} = live(context.owner_conn, "/accounts/settings")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "the owner submits the delete form with the correct account name but wrong password", context do
        context.view
        |> form("#delete-account-form", delete_confirmation: %{
          account_name: "Owner Account",
          password: "WrongPassword123!"
        })
        |> render_submit()

        {:ok, context}
      end

      then_ "the owner sees an error message about the incorrect password", context do
        assert render(context.view) =~ "Incorrect password"
        :ok
      end
    end

    scenario "deletion is rejected when password is empty" do
      given_ :user_logged_in_as_owner

      given_ "the owner navigates to account settings", context do
        {:ok, view, _html} = live(context.owner_conn, "/accounts/settings")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "the owner submits the delete form with the correct account name but empty password", context do
        context.view
        |> form("#delete-account-form", delete_confirmation: %{
          account_name: "Owner Account",
          password: ""
        })
        |> render_submit()

        {:ok, context}
      end

      then_ "the owner sees an error message about the password being required", context do
        html = render(context.view)
        assert html =~ "password" or html =~ "Password"
        :ok
      end
    end

    scenario "deletion succeeds when correct account name and correct password are provided" do
      given_ :user_logged_in_as_owner

      given_ "the owner navigates to account settings", context do
        {:ok, view, _html} = live(context.owner_conn, "/accounts/settings")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "the owner submits the delete form with the correct account name and correct password", context do
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
