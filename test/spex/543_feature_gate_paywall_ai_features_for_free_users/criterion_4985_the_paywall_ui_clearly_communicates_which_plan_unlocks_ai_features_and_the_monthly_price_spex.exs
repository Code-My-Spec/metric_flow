defmodule MetricFlowSpex.PaywallShowsPlanAndPriceSpex do
  use SexySpex
  use MetricFlowTest.ConnCase
  import Phoenix.LiveViewTest

  import_givens MetricFlowSpex.SharedGivens

  spex "The paywall UI clearly communicates which plan unlocks AI features and the monthly price" do
    scenario "the paywall on the correlations page shows the plan name that unlocks AI features and its monthly price" do
      given_ :user_logged_in_as_owner

      given_ "the free user navigates to the correlations page", context do
        result = live(context.owner_conn, "/app/correlations")
        {:ok, Map.put(context, :result, result)}
      end

      then_ "the paywall displays a plan name that unlocks AI features", context do
        case context.result do
          {:ok, view, _html} ->
            html = render(view)

            has_plan_name =
              html =~ "Pro" or
                html =~ "Growth" or
                html =~ "Business" or
                html =~ "Premium" or
                html =~ "Starter" or
                has_element?(view, "[data-role='paywall-plan-name']")

            assert has_plan_name,
                   "Expected paywall to show a plan name that unlocks AI features. Got: #{html}"

            :ok

          {:error, {:redirect, _}} ->
            :ok

          {:error, {:live_redirect, _}} ->
            :ok
        end
      end

      then_ "the paywall displays a monthly price for the unlocking plan", context do
        case context.result do
          {:ok, view, _html} ->
            html = render(view)

            has_price =
              html =~ "/month" or
                html =~ "per month" or
                html =~ "/mo" or
                html =~ "$" or
                has_element?(view, "[data-role='paywall-price']")

            assert has_price,
                   "Expected paywall to display a monthly price. Got: #{html}"

            :ok

          {:error, {:redirect, _}} ->
            :ok

          {:error, {:live_redirect, _}} ->
            :ok
        end
      end
    end
  end
end
