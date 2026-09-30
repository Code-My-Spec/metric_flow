defmodule MetricFlowSpex.Criterion829ClientCustomizesDashboardUnderWhiteLabelingSpex do
  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest

  import MetricFlowSpex.SharedGivens

  spex "Client customizes their own dashboard under white-labeling", criterion: 829 do
    scenario "a client viewing a white-labeled interface customizes their own dashboard normally" do
      given_ :user_logged_in_as_owner
      given_ :owner_has_metrics

      given_ "a client viewing a white-labeled interface", context do
        account = MetricFlowSpex.Fixtures.account_originated_by(context.owner_email)

        agency =
          MetricFlowTest.AgenciesFixtures.agency_with_white_label_fixture(%{
            subdomain: "branded829",
            logo_url: "https://example.com/branded829-logo.png",
            primary_color: "#AABBCC",
            secondary_color: "#CCBBAA"
          })

        MetricFlowTest.AgenciesFixtures.grant_agency_originator_access(agency.id, account.id)

        %Plug.Conn{} = owner_conn = context.owner_conn
        {:ok, Map.put(context, :agency_conn, %{owner_conn | host: "branded829.metricflow.io"})}
      end

      when_ "they customize their own dashboard", context do
        {:ok, new_view, _html} = live(context.agency_conn, "/app/dashboards/new")

        new_view
        |> element("[data-role='add-visualization-btn']")
        |> render_click()

        new_view
        |> element("[phx-click='select_metric'][phx-value-metric='impressions']")
        |> render_click()

        new_view
        |> element("[data-role='confirm-add-btn']")
        |> render_click()

        new_view
        |> element("form[phx-change='validate_name']")
        |> render_change(%{"dashboard" => %{"name" => "My Custom Dashboard"}})

        new_view
        |> element("[data-role='save-dashboard-btn']")
        |> render_click()

        {:ok, context}
      end

      then_ "the customization applies normally, unaffected by the white-labeling", context do
        {:ok, view, html} = live(context.agency_conn, "/app/dashboards")

        assert html =~ "My Custom Dashboard",
               "Expected the newly customized dashboard to appear in the client's dashboard list"

        assert has_element?(view, "[data-role='agency-logo']")

        {:ok, context}
      end
    end
  end
end
