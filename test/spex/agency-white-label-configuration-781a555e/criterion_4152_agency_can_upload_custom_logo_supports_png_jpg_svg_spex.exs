defmodule MetricFlowSpex.AgencyCanUploadCustomLogoSupportsPngJpgSvgSpex do
  use SexySpex
  use MetricFlowTest.ConnCase
  import Phoenix.LiveViewTest

  import_givens MetricFlowSpex.SharedGivens

  spex "Agency can upload custom logo (supports PNG, JPG, SVG)" do
    scenario "agency owner sees a Logo URL field in the White-Label Branding section" do
      given_ :user_logged_in_as_owner

      given_ "the owner navigates to account settings", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/accounts/settings")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "the White-Label Branding section is visible", context do
        assert render(context.view) =~ "White-Label Branding"
        :ok
      end

      then_ "a Logo URL input field is present in the white-label form", context do
        assert has_element?(context.view, "#white-label-form input[name='white_label[logo_url]']")
        :ok
      end
    end

    scenario "agency owner can save a PNG logo URL and sees confirmation" do
      given_ :user_logged_in_as_owner

      given_ "the owner navigates to account settings", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/accounts/settings")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "the owner submits the white-label form with a PNG logo URL", context do
        subdomain = "agency-png-#{System.unique_integer([:positive])}"

        context.view
        |> form("#white-label-form", white_label: %{
          logo_url: "https://cdn.example.com/logo.png",
          subdomain: subdomain,
          primary_color: "#FF5733",
          secondary_color: "#3498DB"
        })
        |> render_submit()

        {:ok, context}
      end

      then_ "a success confirmation message is shown", context do
        assert render(context.view) =~ "White-label settings saved"
        :ok
      end

      then_ "the PNG logo URL is reflected in the rendered page", context do
        assert render(context.view) =~ "https://cdn.example.com/logo.png"
        :ok
      end
    end

    scenario "agency owner can save a JPG logo URL and sees confirmation" do
      given_ :user_logged_in_as_owner

      given_ "the owner navigates to account settings", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/accounts/settings")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "the owner submits the white-label form with a JPG logo URL", context do
        subdomain = "agency-jpg-#{System.unique_integer([:positive])}"

        context.view
        |> form("#white-label-form", white_label: %{
          logo_url: "https://cdn.example.com/brand-logo.jpg",
          subdomain: subdomain,
          primary_color: "#FF5733",
          secondary_color: "#3498DB"
        })
        |> render_submit()

        {:ok, context}
      end

      then_ "a success confirmation message is shown", context do
        assert render(context.view) =~ "White-label settings saved"
        :ok
      end

      then_ "the JPG logo URL is reflected in the rendered page", context do
        assert render(context.view) =~ "https://cdn.example.com/brand-logo.jpg"
        :ok
      end
    end

    scenario "agency owner can save an SVG logo URL and sees confirmation" do
      given_ :user_logged_in_as_owner

      given_ "the owner navigates to account settings", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/accounts/settings")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "the owner submits the white-label form with an SVG logo URL", context do
        subdomain = "agency-svg-#{System.unique_integer([:positive])}"

        context.view
        |> form("#white-label-form", white_label: %{
          logo_url: "https://cdn.example.com/vector-logo.svg",
          subdomain: subdomain,
          primary_color: "#FF5733",
          secondary_color: "#3498DB"
        })
        |> render_submit()

        {:ok, context}
      end

      then_ "a success confirmation message is shown", context do
        assert render(context.view) =~ "White-label settings saved"
        :ok
      end

      then_ "the SVG logo URL is reflected in the rendered page", context do
        assert render(context.view) =~ "https://cdn.example.com/vector-logo.svg"
        :ok
      end
    end
  end
end
