defmodule MetricFlowSpex.IntegrationsListIncludesMarketingAndFinancialPlatformsTogetherSpex do
  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest

  import MetricFlowSpex.SharedGivens

  spex "Integrations list includes marketing and financial platforms together", criterion: 569 do
    scenario "an owner with both QuickBooks and Google Ads connected sees both in one list" do
      given_ :owner_with_quickbooks_integration

      given_ "the user also has a connected marketing platform", context do
        user = MetricFlowTest.UsersFixtures.get_user_by_email(context.owner_email)
        MetricFlowTest.IntegrationsFixtures.integration_fixture(user, %{provider: :google_ads})
        {:ok, context}
      end

      when_ "they open the integrations list", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/integrations")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "both integrations appear together in the same list", context do
        assert has_element?(
                 context.view,
                 "[data-role='integrations-list'] [data-platform='quickbooks']"
               )

        assert has_element?(
                 context.view,
                 "[data-role='integrations-list'] [data-platform='google_ads']"
               )

        {:ok, context}
      end
    end
  end
end
