defmodule MetricFlowSpex.AgencyResetsBrandingToDefaultSpex do
  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest

  import MetricFlowSpex.SharedGivens

  spex "Agency resets branding to default", criterion: 741 do
    scenario "agency owner resets branding and the custom configuration is reverted" do
      given_(:agency_owner_logged_in)

      given_ "the agency has custom logo, colors, and subdomain configured", context do
        subdomain = "agency741-#{System.unique_integer([:positive])}"

        {:ok, view, _html} = live(context.owner_conn, "/app/accounts/settings")

        view
        |> form("#white-label-form",
          white_label: %{
            logo_url: "https://cdn.example.com/logo.png",
            subdomain: subdomain,
            primary_color: "#FF5733",
            secondary_color: "#3498DB"
          }
        )
        |> render_submit()

        assert has_element?(view, "[data-role='reset-white-label']")

        {:ok, Map.merge(context, %{view: view, subdomain: subdomain})}
      end

      when_ "the agency owner resets branding to default", context do
        context.view
        |> element("[data-role='reset-white-label']")
        |> render_click()

        {:ok, context}
      end

      then_ "the custom logo, colors, and subdomain configuration are reverted", context do
        html = render(context.view)
        refute html =~ context.subdomain
        refute html =~ "https://cdn.example.com/logo.png"
        refute has_element?(context.view, "[data-role='reset-white-label']")
        refute has_element?(context.view, "[data-role='dns-verification']")
        {:ok, context}
      end
    end
  end
end
