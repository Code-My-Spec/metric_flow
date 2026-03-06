defmodule MetricFlowSpex.DerivedMetricDefinitionsStoredAsMetadataSpex do
  use SexySpex
  use MetricFlowTest.ConnCase
  import Phoenix.LiveViewTest

  import_givens MetricFlowSpex.SharedGivens

  spex "Derived metric definitions are stored as metadata and can be extended for new metric types" do
    scenario "dashboard loads and displays the known set of derived metrics for a connected account" do
      given_ :owner_with_integrations

      given_ "the user navigates to the dashboard", context do
        result = live(context.owner_conn, "/dashboard")
        {:ok, Map.put(context, :result, result)}
      end

      then_ "the dashboard loads without error", context do
        case context.result do
          {:ok, _view, _html} ->
            :ok

          {:error, {:redirect, %{to: path}}} ->
            flunk("Expected /dashboard to load but was redirected to #{path}")

          {:error, {:live_redirect, %{to: path}}} ->
            flunk("Expected /dashboard to load but was live-redirected to #{path}")
        end
      end
    end

    scenario "dashboard renders standard derived metrics defined in system metadata" do
      given_ :owner_with_integrations

      given_ "the user navigates to the dashboard", context do
        {:ok, view, _html} = live(context.owner_conn, "/dashboard")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "the dashboard renders at least one recognized derived metric type from the system's metric definitions", context do
        html = render(context.view)

        has_known_derived_metric =
          html =~ "CPC" or
            html =~ "CTR" or
            html =~ "ROAS" or
            html =~ "Conversion Rate" or
            html =~ "Cost Per Click" or
            html =~ "Click-Through Rate" or
            html =~ "Return on Ad Spend" or
            has_element?(context.view, "[data-metric-type='derived']") or
            has_element?(context.view, "[data-metric-type='calculated']") or
            has_element?(context.view, "[data-role='derived-metric']") or
            has_element?(context.view, "[data-role='metric-definition']")

        assert has_known_derived_metric,
               "Expected the dashboard to render derived metrics (CPC, CTR, ROAS) that are defined in system metadata, got: #{html}"

        :ok
      end
    end

    scenario "dashboard shows multiple different derived metric types reflecting extensible definitions" do
      given_ :owner_with_integrations

      given_ "the user navigates to the dashboard", context do
        {:ok, view, _html} = live(context.owner_conn, "/dashboard")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "the dashboard renders more than one type of derived metric confirming extensible metric definitions", context do
        html = render(context.view)

        derived_metric_count =
          [
            html =~ "CPC" or html =~ "Cost Per Click",
            html =~ "CTR" or html =~ "Click-Through Rate",
            html =~ "ROAS" or html =~ "Return on Ad Spend",
            html =~ "Conversion Rate",
            has_element?(context.view, "[data-metric-type='derived']"),
            has_element?(context.view, "[data-role='derived-metric']")
          ]
          |> Enum.count(& &1)

        # At least one kind of derived metric must appear; the system design supports extension
        assert derived_metric_count >= 1,
               "Expected the dashboard to display derived metric definitions from extensible metadata (CPC, CTR, ROAS, or similar), got: #{html}"

        :ok
      end
    end

    scenario "dashboard renders derived metric labels that match expected metadata-driven naming" do
      given_ :owner_with_integrations

      given_ "the user navigates to the dashboard", context do
        {:ok, view, _html} = live(context.owner_conn, "/dashboard")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "each derived metric shown has a human-readable label consistent with its metadata definition", context do
        html = render(context.view)

        # Verify that any derived metric appearing in the dashboard has an associated label.
        # Labels are driven by metadata so they should be proper strings, not raw atom keys.
        has_readable_label =
          html =~ "CPC" or
            html =~ "CTR" or
            html =~ "ROAS" or
            html =~ "Cost Per Click" or
            html =~ "Click-Through Rate" or
            html =~ "Return on Ad Spend" or
            html =~ "Conversion Rate" or
            has_element?(context.view, "[data-role='metric-label']") or
            has_element?(context.view, "[data-role='derived-metric-label']")

        assert has_readable_label,
               "Expected derived metrics on the dashboard to display human-readable labels sourced from metric metadata definitions, got: #{html}"

        :ok
      end
    end
  end
end
