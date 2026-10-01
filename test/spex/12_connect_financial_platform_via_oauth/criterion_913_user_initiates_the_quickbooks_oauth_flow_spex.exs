defmodule MetricFlowSpex.UserInitiatesTheQuickbooksOauthFlowSpex do
  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest

  import MetricFlowSpex.SharedGivens

  spex "User initiates the QuickBooks OAuth flow", criterion: 913 do
    scenario "a user wants to connect QuickBooks and starts the connection process" do
      given_ :user_logged_in_as_owner

      given_ "the user wants to connect QuickBooks", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/integrations/connect")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "they start the connection process", context do
        result =
          context.view
          |> element("[data-platform='quickbooks'] [data-role='connect-button']")
          |> render_click()

        {:ok, Map.put(context, :click_result, result)}
      end

      then_ "the OAuth flow begins", context do
        assert {:error, {:redirect, %{to: to}}} = context.click_result
        assert to =~ "/app/integrations/oauth/quickbooks"
        {:ok, context}
      end
    end
  end
end
