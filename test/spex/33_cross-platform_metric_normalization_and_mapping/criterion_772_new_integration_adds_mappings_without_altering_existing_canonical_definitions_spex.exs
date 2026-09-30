defmodule MetricFlowSpex.NewIntegrationAddsMappingsWithoutAlteringExistingCanonicalDefinitionsSpex do
  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest

  import MetricFlowSpex.SharedGivens

  spex "New integration adds mappings without altering existing canonical definitions",
    criterion: 772 do
    scenario "connecting a new platform integration leaves an existing platform's canonical metric unchanged" do
      given_(:user_logged_in_as_owner)

      given_ "an existing set of canonical metric definitions already used by other integrations",
             context do
        MetricFlowSpex.Fixtures.create_integration_for(context.owner_email, :google_ads)

        MetricFlowSpex.Fixtures.create_metric_for(context.owner_email, %{
          provider: :google_ads,
          metric_name: "clicks",
          value: 30.0
        })

        {:ok, view, _html} = live(context.owner_conn, "/app/dashboard")
        assert render(view) =~ "30"

        {:ok, context}
      end

      when_ "a new platform integration is added and defines its own metric mappings", context do
        MetricFlowSpex.Fixtures.create_integration_for(context.owner_email, :facebook_ads)

        MetricFlowSpex.Fixtures.create_metric_for(context.owner_email, %{
          provider: :facebook_ads,
          metric_name: "total_cost",
          value: 15.0
        })

        {:ok, view, _html} = live(context.owner_conn, "/app/dashboard")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "the existing canonical metric definitions are unchanged and unaffected", context do
        html = render(context.view)
        assert html =~ "30"
        assert html =~ "clicks"
        {:ok, context}
      end
    end
  end
end
