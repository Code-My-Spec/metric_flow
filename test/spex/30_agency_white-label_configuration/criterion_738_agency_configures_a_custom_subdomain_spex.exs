defmodule MetricFlowSpex.AgencyConfiguresACustomSubdomainSpex do
  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest

  import MetricFlowSpex.SharedGivens

  spex "Agency configures a custom subdomain", criterion: 738 do
    scenario "agency owner configures a custom subdomain" do
      given_(:agency_owner_logged_in)

      given_ "the agency owner is on the white-label settings page", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/accounts/settings")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "they configure a custom subdomain", context do
        subdomain = "agency738-#{System.unique_integer([:positive])}"

        context.view
        |> form("#white-label-form",
          white_label: %{
            subdomain: subdomain,
            primary_color: "#FF5733",
            secondary_color: "#3498DB"
          }
        )
        |> render_submit()

        {:ok, Map.put(context, :subdomain, subdomain)}
      end

      then_ "it is saved pending DNS verification", context do
        html = render(context.view)
        assert html =~ context.subdomain
        assert has_element?(context.view, "[data-role='dns-verification']")

        assert has_element?(
                 context.view,
                 "[data-role='dns-verification'] .badge-warning",
                 "Pending"
               )

        refute has_element?(context.view, "[data-role='dns-verification'] .badge-success")
        {:ok, context}
      end
    end
  end
end
