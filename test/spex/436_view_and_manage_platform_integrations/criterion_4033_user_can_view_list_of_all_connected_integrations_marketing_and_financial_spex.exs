defmodule MetricFlowSpex.UserCanViewListOfAllConnectedIntegrationsMarketingAndFinancialSpex do
  use SexySpex
  use MetricFlowTest.ConnCase
  import Phoenix.LiveViewTest

  import_givens MetricFlowSpex.SharedGivens

  spex "User can view list of all connected integrations (marketing and financial)" do
    scenario "authenticated user can navigate to the integrations index page" do
      given_ :user_logged_in_as_owner

      given_ "the user navigates to the integrations page", context do
        result = live(context.owner_conn, "/app/integrations")
        {:ok, Map.put(context, :result, result)}
      end

      then_ "the integrations page loads successfully", context do
        case context.result do
          {:ok, _view, _html} ->
            :ok

          {:error, {:redirect, %{to: path}}} ->
            flunk("Expected /integrations to load but was redirected to #{path}")

          {:error, {:live_redirect, %{to: path}}} ->
            flunk("Expected /integrations to load but was live-redirected to #{path}")
        end
      end
    end

    scenario "integrations index page renders an integrations list section" do
      given_ :user_logged_in_as_owner

      given_ "the user navigates to the integrations page", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/integrations")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "the page shows a heading or section for integrations", context do
        html = render(context.view)

        assert html =~ "Integration" or
                 html =~ "integration" or
                 has_element?(context.view, "[data-role='integrations-list']") or
                 has_element?(context.view, "[data-role='integrations-index']")

        :ok
      end
    end

    scenario "integrations index page shows marketing platforms" do
      given_ :user_logged_in_as_owner

      given_ "the user navigates to the integrations page", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/integrations")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "the page references marketing platform integrations", context do
        html = render(context.view)

        assert html =~ "Google Ads" or
                 html =~ "Facebook Ads" or
                 html =~ "Google Analytics" or
                 html =~ "marketing" or
                 html =~ "Marketing" or
                 has_element?(context.view, "[data-platform]")

        :ok
      end
    end

    scenario "integrations index page shows financial platforms" do
      given_ :user_logged_in_as_owner

      given_ "the user navigates to the integrations page", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/integrations")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "the page references financial platform integrations", context do
        html = render(context.view)

        assert html =~ "QuickBooks" or
                 html =~ "Stripe" or
                 html =~ "financial" or
                 html =~ "Financial" or
                 html =~ "accounting" or
                 html =~ "Accounting" or
                 has_element?(context.view, "[data-platform]")

        :ok
      end
    end

    scenario "unauthenticated user cannot access the integrations index page" do
      given_ "an unauthenticated user navigates to the integrations page", context do
        result = live(build_conn(), "/app/integrations")
        {:ok, Map.put(context, :result, result)}
      end

      then_ "the user is redirected away from the integrations page", context do
        case context.result do
          {:error, {:redirect, _}} ->
            :ok

          {:error, {:live_redirect, _}} ->
            :ok

          {:ok, view, _html} ->
            refute render(view) =~ "Integration"
            :ok
        end
      end
    end
  end
end
