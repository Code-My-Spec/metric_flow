defmodule MetricFlowSpex.UserCanSeeWhichAdAccountsPropertiesOrIncomeAccountsAreSelectedForEachIntegrationSpex do
  use SexySpex
  use MetricFlowTest.ConnCase
  import Phoenix.LiveViewTest

  import_givens MetricFlowSpex.SharedGivens

  spex "User can see which ad accounts, properties, or income accounts are selected for each integration" do
    scenario "the integrations page shows selected accounts for each marketing integration" do
      given_ :user_logged_in_as_owner

      given_ "the user navigates to the integrations page", context do
        {:ok, view, _html} = live(context.owner_conn, "/integrations")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "each integration entry contains a section listing selected accounts", context do
        assert has_element?(context.view, "[data-role='integration-selected-accounts']")
        :ok
      end
    end

    scenario "the integrations page shows selected properties for analytics integrations" do
      given_ :user_logged_in_as_owner

      given_ "the user navigates to the integrations page", context do
        {:ok, view, _html} = live(context.owner_conn, "/integrations")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "the page contains elements that display selected properties or accounts per integration", context do
        assert has_element?(context.view, "[data-role='integration-row']")
        :ok
      end

      then_ "each integration row shows the accounts or properties selected for syncing", context do
        assert has_element?(context.view, "[data-role='integration-row'] [data-role='integration-selected-accounts']")
        :ok
      end
    end

    scenario "the integrations page shows selected income accounts for financial integrations" do
      given_ :user_logged_in_as_owner

      given_ "the user navigates to the integrations page", context do
        {:ok, view, _html} = live(context.owner_conn, "/integrations")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "the page contains an element for displaying selected income accounts", context do
        assert has_element?(context.view, "[data-role='integration-selected-accounts']")
        :ok
      end
    end

    scenario "user can navigate to the detail page for an integration to view selected accounts" do
      given_ :user_logged_in_as_owner

      given_ "the user navigates to the integrations page", context do
        {:ok, view, _html} = live(context.owner_conn, "/integrations")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "the integrations page has a link or button to view details for each integration", context do
        assert has_element?(context.view, "[data-role='integration-detail-link']")
        :ok
      end
    end
  end
end
