defmodule MetricFlowSpex.Criterion978NonNumericMetricValueStoredAsZeroSpex do
  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest

  import MetricFlowSpex.SharedGivens

  spex "A non-numeric metric value in the API response is stored as zero rather than failing the whole sync",
       criterion: 978 do
    scenario "a Facebook Ads API response includes a non-numeric metric value for a day" do
      given_ :user_logged_in_as_owner

      given_ "a Facebook Ads account's API response includes a non-numeric metric value for a day", context do
        MetricFlowSpex.Fixtures.create_integration_for(context.owner_email, :facebook_ads,
          provider_metadata: %{"ad_account_id" => "123456789"}
        )

        {:ok, context}
      end

      when_ "the sync processes that day", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/integrations/sync-history")
        view |> element("[data-role='trigger-daily-sync']") |> render_click()
        Oban.drain_queue(queue: :sync)
        {:ok, Map.put(context, :view, view)}
      end

      then_ "the non-numeric value is stored as zero rather than failing the whole sync", context do
        assert has_element?(
                 context.view,
                 "[data-role='sync-history-entry'][data-status='success'] [data-role='sync-provider']",
                 "Facebook Ads"
               )

        {:ok, context}
      end
    end
  end
end
