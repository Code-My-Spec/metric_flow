defmodule MetricFlowSpex.UserCanInitiateOauthFlowForQuickbooksSpex do
  use SexySpex
  use MetricFlowTest.ConnCase
  import Phoenix.LiveViewTest

  import_givens MetricFlowSpex.SharedGivens

  spex "User can initiate OAuth flow for QuickBooks" do
    scenario "the connect page displays QuickBooks as an available platform" do
      given_ :user_logged_in_as_owner

      given_ "the user navigates to the connect page", context do
        {:ok, view, _html} = live(context.owner_conn, "/integrations/connect")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "QuickBooks is shown as a connectable platform", context do
        html = render(context.view)
        assert html =~ "QuickBooks"
        :ok
      end
    end

    scenario "clicking connect for QuickBooks initiates the OAuth flow" do
      given_ :user_logged_in_as_owner

      given_ "the user navigates to the connect page", context do
        {:ok, view, _html} = live(context.owner_conn, "/integrations/connect")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "the user clicks the connect button for QuickBooks", context do
        view = context.view
        result = element(view, "[data-platform='quickbooks'] [data-role='connect-button']") |> render_click()
        {:ok, Map.put(context, :click_result, result)}
      end

      then_ "the user is redirected to the QuickBooks OAuth authorization page", context do
        assert {:error, {:redirect, %{to: url}}} = context.click_result
        assert url =~ "quickbooks" or url =~ "intuit"
        :ok
      end
    end

    scenario "QuickBooks shows not connected status when no integration exists" do
      given_ :user_logged_in_as_owner

      given_ "the user navigates to the connect page", context do
        {:ok, view, _html} = live(context.owner_conn, "/integrations/connect")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "QuickBooks shows a not connected badge", context do
        assert has_element?(context.view, "[data-platform='quickbooks']")
        html = render(context.view)
        assert html =~ "Not connected"
        :ok
      end
    end
  end
end
