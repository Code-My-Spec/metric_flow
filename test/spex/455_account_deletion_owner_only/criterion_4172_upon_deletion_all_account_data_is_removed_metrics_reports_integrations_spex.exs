defmodule MetricFlowSpex.UponDeletionAllAccountDataIsRemovedMetricsReportsIntegrationsSpex do
  use SexySpex
  use MetricFlowTest.ConnCase
  import Phoenix.LiveViewTest

  import_givens MetricFlowSpex.SharedGivens

  spex "Upon deletion, all account data is removed (metrics, reports, integrations)" do
    scenario "after account deletion, the deleted account no longer appears in the accounts list" do
      given_ :user_logged_in_as_owner

      given_ "the owner navigates to account settings", context do
        {:ok, view, _html} = live(context.owner_conn, "/accounts/settings")
        {:ok, Map.put(context, :settings_view, view)}
      end

      when_ "the owner deletes the account with correct name and password", context do
        context.settings_view
        |> form("#delete-account-form", delete_confirmation: %{
          account_name: "Owner Account",
          password: context.owner_password
        })
        |> render_submit()

        {:ok, context}
      end

      then_ "the owner is redirected to the accounts list", context do
        assert_redirect(context.settings_view, "/accounts")
        :ok
      end

      given_ "the owner follows the redirect to the accounts list", context do
        {:ok, accounts_view, _html} = live(context.owner_conn, "/accounts")
        {:ok, Map.put(context, :accounts_view, accounts_view)}
      end

      then_ "the deleted account does not appear in the accounts list", context do
        refute render(context.accounts_view) =~ "Owner Account"
        :ok
      end
    end

    scenario "after account deletion, user cannot access the deleted account's settings" do
      given_ :user_logged_in_as_owner

      given_ "the owner navigates to account settings", context do
        {:ok, view, _html} = live(context.owner_conn, "/accounts/settings")
        {:ok, Map.put(context, :settings_view, view)}
      end

      when_ "the owner deletes the account with correct name and password", context do
        context.settings_view
        |> form("#delete-account-form", delete_confirmation: %{
          account_name: "Owner Account",
          password: context.owner_password
        })
        |> render_submit()

        {:ok, context}
      end

      then_ "the owner is redirected away from the deleted account", context do
        assert_redirect(context.settings_view, "/accounts")
        :ok
      end

      then_ "navigating to the deleted account's settings results in an error or redirect", context do
        result = live(context.owner_conn, "/accounts/settings")

        case result do
          {:error, {:redirect, %{to: path}}} ->
            refute path == "/accounts/settings"

          {:error, {:live_redirect, %{to: path}}} ->
            refute path == "/accounts/settings"

          {:ok, view, _html} ->
            html = render(view)
            refute html =~ "Owner Account"
        end

        :ok
      end
    end
  end
end
