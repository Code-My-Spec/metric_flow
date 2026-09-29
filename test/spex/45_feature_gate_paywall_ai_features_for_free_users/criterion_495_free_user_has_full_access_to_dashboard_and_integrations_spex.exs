defmodule MetricFlowSpex.FreeUserHasFullAccessToDashboardAndIntegrationsSpex do
  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest

  import MetricFlowSpex.SharedGivens

  spex "Free user has full access to Dashboard and Integrations", criterion: 495 do
    scenario "Dana on the free plan opens the Dashboard" do
      given_ :user_logged_in_as_owner

      when_ "Dana opens the Dashboard", context do
        result = live(context.owner_conn, "/app/dashboard")
        {:ok, Map.put(context, :result, result)}
      end

      then_ "she sees the full content with no gate or upgrade prompt", context do
        case context.result do
          {:ok, view, _html} ->
            html = render(view)

            refute has_element?(view, "[data-role='paywall']") or
                     has_element?(view, "[data-role='upgrade-modal']"),
                   "Expected no paywall on /dashboard for free user. Got: #{html}"

            {:ok, context}

          {:error, {:redirect, %{to: path}}} ->
            flunk("Expected /dashboard to load but was redirected to #{path}")

          {:error, {:live_redirect, %{to: path}}} ->
            flunk("Expected /dashboard to load but was live-redirected to #{path}")
        end
      end
    end

    scenario "Dana on the free plan opens an Integrations page" do
      given_ :user_logged_in_as_owner

      when_ "Dana opens an Integrations page", context do
        result = live(context.owner_conn, "/app/integrations")
        {:ok, Map.put(context, :result, result)}
      end

      then_ "she sees the full content with no gate or upgrade prompt", context do
        case context.result do
          {:ok, view, _html} ->
            html = render(view)

            refute has_element?(view, "[data-role='paywall']") or
                     has_element?(view, "[data-role='upgrade-modal']"),
                   "Expected no paywall on /integrations for free user. Got: #{html}"

            {:ok, context}

          {:error, {:redirect, %{to: path}}} ->
            flunk("Expected /integrations to load but was redirected to #{path}")

          {:error, {:live_redirect, %{to: path}}} ->
            flunk("Expected /integrations to load but was live-redirected to #{path}")
        end
      end
    end
  end
end
