defmodule MetricFlowSpex.AgencyWithNoConfiguredPlansShowsNothingToSubscribeToSpex do
  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest

  import MetricFlowSpex.SharedGivens

  spex "Agency with no configured plans shows nothing to subscribe to", criterion: 485 do
    scenario "a customer of an agency with no plans visits checkout" do
      given_ :user_logged_in_as_owner

      when_ "the customer navigates to checkout", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/subscriptions/checkout")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "no purchasable plan is shown, and the platform's own default plan is not offered instead", context do
        html = render(context.view)
        refute html =~ "subscribe-button"
        refute html =~ "$49.99"
        {:ok, context}
      end
    end
  end
end
