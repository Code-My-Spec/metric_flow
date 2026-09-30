defmodule MetricFlowSpex.AgencyUploadsASupportedLogoFormatSpex do
  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest

  import MetricFlowSpex.SharedGivens

  spex "Agency uploads a supported logo format", criterion: 735 do
    scenario "agency owner uploads a PNG logo and it is accepted and saved" do
      given_(:agency_owner_logged_in)

      given_ "the agency owner is on the white-label settings page", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/accounts/settings")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "they upload a PNG logo", context do
        subdomain = "agency735-#{System.unique_integer([:positive])}"

        context.view
        |> form("#white-label-form",
          white_label: %{
            logo_url: "https://cdn.example.com/logo.png",
            subdomain: subdomain,
            primary_color: "#FF5733",
            secondary_color: "#3498DB"
          }
        )
        |> render_submit()

        {:ok, context}
      end

      then_ "the logo is accepted and saved", context do
        html = render(context.view)
        assert html =~ "White-label settings saved"
        assert html =~ "https://cdn.example.com/logo.png"
        {:ok, context}
      end
    end
  end
end
