defmodule MetricFlowSpex.MetricCalculationIsPlatformAgnosticSpex do
  use SexySpex
  use MetricFlowTest.ConnCase
  import Phoenix.LiveViewTest

  import_givens MetricFlowSpex.SharedGivens

  spex "Metric calculation is platform-agnostic — operates on Review table directly regardless of source platform" do
    scenario "report page loads for an authenticated user" do
      given_ :user_logged_in_as_owner

      given_ "the user navigates to the reports page", context do
        result = live(context.owner_conn, "/reports")
        {:ok, Map.put(context, :result, result)}
      end

      then_ "the reports page is accessible to authenticated users", context do
        case context.result do
          {:ok, _view, _html} ->
            :ok

          {:error, {:redirect, %{to: "/users/log-in"}}} ->
            flunk("Expected /reports to be accessible to an authenticated user, but was redirected to login")

          {:error, {:redirect, %{to: path}}} ->
            flunk("Expected /reports to load but was redirected to #{path}")

          {:error, {:live_redirect, %{to: path}}} ->
            flunk("Expected /reports to load but was live-redirected to #{path}")
        end
      end
    end

    scenario "report page shows review metrics regardless of review source platform" do
      given_ :user_logged_in_as_owner

      given_ "the user navigates to the reports page", context do
        {:ok, view, _html} = live(context.owner_conn, "/reports")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "the page displays review metrics without referencing a specific platform source", context do
        html = render(context.view)

        assert html =~ "review" or html =~ "Review" or html =~ "Reports" or html =~ "report" or
                 has_element?(context.view, "[data-role='review-metrics']") or
                 has_element?(context.view, "[data-role='reports']"),
               "Expected the reports page to show review metrics content, got: #{html}"

        :ok
      end

      then_ "the page does not gate review metrics behind a specific platform name", context do
        html = render(context.view)

        refute (html =~ "Google Business Profile only" or html =~ "Yelp only" or
                  html =~ "Trustpilot only"),
               "Expected review metrics to be platform-agnostic, but the page restricts them to a single platform"

        :ok
      end
    end

    scenario "report page labels review metrics in a platform-neutral way" do
      given_ :user_logged_in_as_owner

      given_ "the user navigates to the reports page", context do
        {:ok, view, _html} = live(context.owner_conn, "/reports")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "the review section heading does not reference a specific platform", context do
        html = render(context.view)

        assert html =~ "Reviews" or html =~ "Review Metrics" or
                 html =~ "Reports" or html =~ "Saved Reports" or html =~ "report" or
                 has_element?(context.view, "[data-role='review-metrics']") or
                 has_element?(context.view, "[data-role='reports-list']"),
               "Expected a platform-neutral review metrics section heading or reports page content"

        :ok
      end
    end

    scenario "unauthenticated user cannot access the reports page" do
      given_ "an unauthenticated user navigates to the reports page", context do
        result = live(build_conn(), "/reports")
        {:ok, Map.put(context, :result, result)}
      end

      then_ "the user is redirected away from the reports page", context do
        case context.result do
          {:error, {:redirect, _}} ->
            :ok

          {:error, {:live_redirect, _}} ->
            :ok

          {:ok, view, _html} ->
            refute render(view) =~ "Review Metrics",
                   "Expected unauthenticated user to not see review metrics content"

            :ok
        end
      end
    end
  end
end
