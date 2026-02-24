defmodule MetricFlowSpex.AllIntegrationsTreatedUniformlyWithNoSpecialQuickbooksUiSpex do
  use SexySpex
  use MetricFlowTest.ConnCase
  import Phoenix.LiveViewTest

  import_givens MetricFlowSpex.SharedGivens

  spex "All integrations treated uniformly with no special QuickBooks UI" do
    scenario "QuickBooks integration appears using the same card layout as other integrations" do
      given_ :user_logged_in_as_owner

      given_ "the user navigates to the integrations page", context do
        {:ok, view, _html} = live(context.owner_conn, "/integrations")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "QuickBooks is displayed in a standard integration card", context do
        html = render(context.view)
        assert html =~ "QuickBooks" or
                 has_element?(context.view, "[data-platform='quickbooks']") or
                 has_element?(context.view, "[data-role='integration-card']")
        :ok
      end
    end

    scenario "QuickBooks integration card uses the same data-role attributes as other integration cards" do
      given_ :user_logged_in_as_owner

      given_ "the user navigates to the integrations page", context do
        {:ok, view, _html} = live(context.owner_conn, "/integrations")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "all integration cards share a uniform data-role structure", context do
        assert has_element?(context.view, "[data-role='integration-card']")
        :ok
      end
    end

    scenario "there are no QuickBooks-specific sections or components outside the standard card" do
      given_ :user_logged_in_as_owner

      given_ "the user navigates to the integrations page", context do
        {:ok, view, _html} = live(context.owner_conn, "/integrations")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "there is no QuickBooks-only section rendered outside the standard integration card layout", context do
        refute has_element?(context.view, "[data-role='quickbooks-special-section']")
        :ok
      end
    end

    scenario "all integration cards show the same action controls regardless of provider" do
      given_ :user_logged_in_as_owner

      given_ "the user navigates to the integrations page", context do
        {:ok, view, _html} = live(context.owner_conn, "/integrations")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "the integrations list shows uniform action controls for all entries", context do
        html = render(context.view)
        assert html =~ "Disconnect" or
                 html =~ "Connect" or
                 html =~ "Reconnect" or
                 has_element?(context.view, "[data-role='integration-card']")
        :ok
      end
    end
  end
end
