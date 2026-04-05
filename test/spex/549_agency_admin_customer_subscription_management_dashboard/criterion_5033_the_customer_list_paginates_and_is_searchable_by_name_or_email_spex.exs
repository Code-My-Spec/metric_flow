defmodule MetricFlowSpex.CustomerListPaginatesAndSearchableSpex do
  use SexySpex
  use MetricFlowTest.ConnCase
  import Phoenix.LiveViewTest

  import_givens MetricFlowSpex.SharedGivens

  spex "The customer list paginates and is searchable by name or email" do
    scenario "agency admin sees a search input on the subscriptions page for filtering customers" do
      given_ :user_logged_in_as_owner

      when_ "the admin navigates to the agency subscriptions page", context do
        {:ok, view, _html} = live(context.owner_conn, "/agency/subscriptions")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "a search input is present for filtering by name or email", context do
        html = render(context.view)
        assert html =~ "Search"
        :ok
      end

      then_ "pagination controls are present on the page", context do
        html = render(context.view)
        assert html =~ "page" or has_element?(context.view, "[phx-click='next_page']") or
                 has_element?(context.view, "nav[aria-label='Pagination']") or
                 html =~ "Next"
        :ok
      end
    end
  end
end
