defmodule MetricFlowSpex.AgencySetsACustomColorSchemeSpex do
  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest

  import MetricFlowSpex.SharedGivens

  spex "Agency sets a custom color scheme", criterion: 737 do
    scenario "agency owner sets primary, secondary, and accent colors" do
      given_(:agency_owner_logged_in)

      given_ "the agency owner is on the white-label settings page", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/accounts/settings")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "they set primary, secondary, and accent colors", context do
        subdomain = "agency737-#{System.unique_integer([:positive])}"

        context.view
        |> form("#white-label-form",
          white_label: %{
            subdomain: subdomain,
            primary_color: "#111111",
            secondary_color: "#222222",
            accent_color: "#333333"
          }
        )
        |> render_submit()

        {:ok, context}
      end

      then_ "those colors are saved as the agency's color scheme", context do
        html = render(context.view)
        assert html =~ "#111111"
        assert html =~ "#222222"
        assert html =~ "#333333"
        {:ok, context}
      end
    end
  end
end
