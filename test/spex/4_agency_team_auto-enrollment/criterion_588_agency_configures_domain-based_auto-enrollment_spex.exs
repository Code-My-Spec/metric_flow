defmodule MetricFlowSpex.AgencyConfiguresDomainBasedAutoEnrollmentSpex do
  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest

  import MetricFlowSpex.SharedGivens

  spex "Agency configures domain-based auto-enrollment", criterion: 588 do
    scenario "an agency owner configures auto-enrollment for their organization's email domain" do
      given_ :agency_owner_logged_in

      given_ "the owner is on their agency settings page", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/accounts/settings")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "they configure auto-enrollment for their organization's email domain", context do
        context.view
        |> form("#auto-enrollment-form", auto_enrollment: %{domain: "myorg588.com"})
        |> render_submit()

        {:ok, context}
      end

      then_ "the domain is saved as the agency's auto-enrollment domain", context do
        assert render(context.view) =~ "myorg588.com"
        {:ok, context}
      end
    end
  end
end
