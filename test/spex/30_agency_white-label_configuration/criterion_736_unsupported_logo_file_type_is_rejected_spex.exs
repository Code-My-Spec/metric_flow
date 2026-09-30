defmodule MetricFlowSpex.UnsupportedLogoFileTypeIsRejectedSpex do
  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest

  import MetricFlowSpex.SharedGivens

  spex "Unsupported logo file type is rejected", criterion: 736 do
    scenario "agency owner tries to upload a logo that is not PNG, JPG, or SVG" do
      given_(:agency_owner_logged_in)

      given_ "the agency owner selects a file that is not PNG, JPG, or SVG", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/accounts/settings")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "they try to upload it as the logo", context do
        subdomain = "agency736-#{System.unique_integer([:positive])}"

        context.view
        |> form("#white-label-form",
          white_label: %{
            logo_url: "https://cdn.example.com/logo.exe",
            subdomain: subdomain,
            primary_color: "#FF5733",
            secondary_color: "#3498DB"
          }
        )
        |> render_submit()

        {:ok, context}
      end

      then_ "the upload is rejected with an error", context do
        html = render(context.view)
        refute html =~ "White-label settings saved"
        assert html =~ "is invalid" or html =~ "unsupported" or html =~ "must be"
        {:ok, context}
      end
    end
  end
end
