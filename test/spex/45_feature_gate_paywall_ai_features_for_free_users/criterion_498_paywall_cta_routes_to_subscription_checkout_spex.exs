defmodule MetricFlowSpex.PaywallCtaRoutesToSubscriptionCheckoutSpex do
  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest

  import MetricFlowSpex.SharedGivens

  spex "Paywall CTA routes to subscription checkout", criterion: 498 do
    scenario "Dana clicks the upgrade call-to-action on the paywall modal" do
      given_ :user_logged_in_as_owner

      given_ "Dana is viewing the paywall modal", context do
        result = live(context.owner_conn, "/app/correlations")
        {:ok, Map.put(context, :result, result)}
      end

      when_ "she clicks the upgrade call-to-action", context do
        click_result =
          case context.result do
            {:ok, view, _html} ->
              cta_selector =
                cond do
                  has_element?(view, "[data-role='paywall-cta']") -> "[data-role='paywall-cta']"
                  has_element?(view, "[data-role='upgrade-cta']") -> "[data-role='upgrade-cta']"
                  has_element?(view, "a[href='/app/subscriptions/checkout']") ->
                    "a[href='/app/subscriptions/checkout']"

                  true ->
                    :no_modal_cta
                end

              case cta_selector do
                :no_modal_cta -> {:error, :no_cta_found}
                selector -> {:ok, view, view |> element(selector) |> render_click()}
              end

            {:error, _} ->
              {:error, :no_paywall_modal_shown}
          end

        {:ok, Map.put(context, :click_result, click_result)}
      end

      then_ "she is taken into the subscription checkout flow", context do
        case context.click_result do
          {:error, :no_paywall_modal_shown} ->
            flunk("Expected Dana to be viewing a paywall modal to click through, but no modal was shown")

          {:error, :no_cta_found} ->
            flunk("Expected a clickable upgrade CTA on the paywall, but none was found")

          {:ok, view, _click_html} ->
            assert_redirect(view, "/app/subscriptions/checkout")
            {:ok, context}
        end
      end
    end
  end
end
