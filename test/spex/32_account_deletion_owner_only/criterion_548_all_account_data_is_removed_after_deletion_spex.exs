defmodule MetricFlowSpex.AllAccountDataIsRemovedAfterDeletionSpex do
  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest

  import MetricFlowSpex.SharedGivens

  spex "All account data is removed after deletion", criterion: 548 do
    scenario "owner's account with metrics and integrations is fully removed after deletion" do
      given_ :owner_with_integrations
      given_ :owner_has_metrics

      when_ "Alex completes account deletion", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/accounts/settings")

        view
        |> form("#delete-account-form", delete_confirmation: %{
          account_name: "Owner Account",
          password: context.owner_password
        })
        |> render_submit()

        {:ok, Map.put(context, :settings_view, view)}
      end

      then_ "the owner is redirected away from the deleted account", context do
        assert_redirect(context.settings_view, "/app/accounts")
        {:ok, context}
      end

      then_ "all of that data is removed from the system along with the account", context do
        result = live(context.owner_conn, "/app/accounts/settings")

        case result do
          {:error, {:redirect, %{to: path}}} ->
            refute path == "/app/accounts/settings"

          {:error, {:live_redirect, %{to: path}}} ->
            refute path == "/app/accounts/settings"

          {:ok, view, _html} ->
            html = render(view)
            refute html =~ "Owner Account"
        end

        {:ok, context}
      end
    end
  end
end
