defmodule MetricFlowSpex.AgencyCanSetCustomColorSchemePrimarySecondaryAccentColorsSpex do
  use SexySpex
  use MetricFlowTest.ConnCase
  import Phoenix.LiveViewTest

  import_givens MetricFlowSpex.SharedGivens

  spex "Agency can set custom color scheme (primary, secondary, accent colors)" do
    scenario "agency owner sees color scheme inputs in the White-Label Branding section" do
      given_ :user_logged_in_as_owner

      given_ "the owner navigates to account settings", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/accounts/settings")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "the White-Label Branding section is visible", context do
        assert render(context.view) =~ "White-Label Branding"
        :ok
      end

      then_ "a Primary Color input field is present in the white-label form", context do
        assert has_element?(context.view, "#white-label-form input[name='white_label[primary_color]']")
        :ok
      end

      then_ "a Secondary Color input field is present in the white-label form", context do
        assert has_element?(context.view, "#white-label-form input[name='white_label[secondary_color]']")
        :ok
      end
    end

    scenario "agency owner can set a custom primary color and sees it saved" do
      given_ :user_logged_in_as_owner

      given_ "the owner navigates to account settings", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/accounts/settings")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "the owner submits the white-label form with a custom primary color", context do
        context.view
        |> form("#white-label-form", white_label: %{
          primary_color: "#1A2B3C",
          secondary_color: "#FFFFFF",
          logo_url: "",
          subdomain: "color-primary-#{System.unique_integer([:positive])}"
        })
        |> render_submit()

        {:ok, context}
      end

      then_ "a success confirmation message is shown", context do
        assert render(context.view) =~ "White-label settings saved"
        :ok
      end

      then_ "the primary color value is reflected in the rendered page", context do
        assert render(context.view) =~ "#1A2B3C"
        :ok
      end
    end

    scenario "agency owner can set a custom secondary color and sees it saved" do
      given_ :user_logged_in_as_owner

      given_ "the owner navigates to account settings", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/accounts/settings")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "the owner submits the white-label form with a custom secondary color", context do
        context.view
        |> form("#white-label-form", white_label: %{
          primary_color: "#000000",
          secondary_color: "#E74C3C",
          logo_url: "",
          subdomain: "color-secondary-#{System.unique_integer([:positive])}"
        })
        |> render_submit()

        {:ok, context}
      end

      then_ "a success confirmation message is shown", context do
        assert render(context.view) =~ "White-label settings saved"
        :ok
      end

      then_ "the secondary color value is reflected in the rendered page", context do
        assert render(context.view) =~ "#E74C3C"
        :ok
      end
    end

    scenario "agency owner can set all three colors together and sees them saved" do
      given_ :user_logged_in_as_owner

      given_ "the owner navigates to account settings", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/accounts/settings")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "the owner submits the white-label form with all three custom colors", context do
        context.view
        |> form("#white-label-form", white_label: %{
          primary_color: "#3498DB",
          secondary_color: "#2ECC71",
          logo_url: "",
          subdomain: "color-all-#{System.unique_integer([:positive])}"
        })
        |> render_submit()

        {:ok, context}
      end

      then_ "a success confirmation message is shown", context do
        assert render(context.view) =~ "White-label settings saved"
        :ok
      end

      then_ "the primary color is reflected in the rendered page", context do
        assert render(context.view) =~ "#3498DB"
        :ok
      end

      then_ "the secondary color is reflected in the rendered page", context do
        assert render(context.view) =~ "#2ECC71"
        :ok
      end
    end
  end
end
