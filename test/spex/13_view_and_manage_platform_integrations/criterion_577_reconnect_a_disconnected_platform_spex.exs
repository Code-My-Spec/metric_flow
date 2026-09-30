defmodule MetricFlowSpex.ReconnectADisconnectedPlatformSpex do
  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest

  import MetricFlowSpex.SharedGivens

  spex "Reconnect a disconnected platform", criterion: 577 do
    scenario "a previously disconnected integration is reconnected" do
      given_ :user_logged_in_as_owner

      given_ "the user has a previously disconnected integration", context do
        {:ok, context}
      end

      when_ "the user reconnects it", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/integrations")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "syncing resumes going forward from the point of reconnection", context do
        assert has_element?(context.view, "[data-role='reconnect-integration']")
        {:ok, context}
      end
    end
  end
end
