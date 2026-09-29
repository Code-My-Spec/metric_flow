defmodule MetricFlowSpex.PaywallStatesTheUnlockingPlanAndItsPriceSpex do
  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest

  import MetricFlowSpex.SharedGivens

  spex "Paywall states the unlocking plan and its price", criterion: 497 do
    scenario "Dana is shown the paywall modal for an AI feature" do
      given_ :user_logged_in_as_owner

      given_ "Dana is shown the paywall modal for an AI feature", context do
        result = live(context.owner_conn, "/app/correlations")
        {:ok, Map.put(context, :result, result)}
      end

      when_ "she reads the modal", context do
        html =
          case context.result do
            {:ok, view, _html} -> render(view)
            {:error, {:redirect, %{flash: flash}}} -> flash |> Map.values() |> Enum.join(" ")
            {:error, {:live_redirect, %{flash: flash}}} -> flash |> Map.values() |> Enum.join(" ")
            _ -> ""
          end

        {:ok, Map.put(context, :html, html)}
      end

      then_ "it names the plan that unlocks AI features", context do
        has_plan_name =
          context.html =~ "Pro" or context.html =~ "Growth" or context.html =~ "Business" or
            context.html =~ "Premium" or context.html =~ "Starter"

        assert has_plan_name,
               "Expected the paywall modal to name the unlocking plan. Got: #{context.html}"

        {:ok, context}
      end

      then_ "it shows the plan's monthly price", context do
        has_price =
          context.html =~ "/month" or context.html =~ "per month" or context.html =~ "/mo" or
            context.html =~ "$"

        assert has_price, "Expected the paywall modal to show a monthly price. Got: #{context.html}"
        {:ok, context}
      end
    end
  end
end
