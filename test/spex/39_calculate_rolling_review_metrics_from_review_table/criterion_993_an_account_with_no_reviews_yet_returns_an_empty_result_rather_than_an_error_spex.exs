defmodule MetricFlowSpex.AccountWithNoReviewsReturnsEmptyResultNotErrorSpex do
  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest

  import MetricFlowSpex.SharedGivens

  spex "An account with no reviews yet returns an empty result rather than an error",
       criterion: 993 do
    scenario "viewing the review metrics dashboard before any reviews have synced renders an empty state, not an error" do
      given_ :user_logged_in_as_owner

      given_ "the account is connected to a review-producing platform but has no reviews yet",
             context do
        MetricFlowSpex.Fixtures.create_integration_for(context.owner_email, :google_business,
          provider_metadata: %{"email" => context.owner_email}
        )

        {:ok, context}
      end

      when_ "the user views the review metrics dashboard", context do
        {:ok, view, html} =
          live(context.owner_conn, "/app/integrations/google_business/dashboard")

        {:ok, Map.merge(context, %{view: view, html: html})}
      end

      then_ "an empty result is shown rather than an error", context do
        assert has_element?(context.view, "[data-role='no-review-data']")
        assert has_element?(context.view, "span", "Connected")
        {:ok, context}
      end
    end
  end
end
