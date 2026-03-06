defmodule MetricFlowSpex.AgencyCanResetToDefaultBrandingSpex do
  use SexySpex
  use MetricFlowTest.ConnCase
  import Phoenix.LiveViewTest

  import_givens MetricFlowSpex.SharedGivens

  spex "Agency can reset to default branding" do
    scenario "agency owner with custom branding sees a Reset to Default button" do
      given_ :user_logged_in_as_owner

      given_ "the owner has saved custom branding settings", context do
        {:ok, view, _html} = live(context.owner_conn, "/accounts/settings")

        view
        |> form("#white-label-form", white_label: %{
          logo_url: "https://cdn.example.com/logo.png",
          subdomain: "reset-#{System.unique_integer([:positive])}",
          primary_color: "#FF5733",
          secondary_color: "#3498DB"
        })
        |> render_submit()

        {:ok, Map.put(context, :view, view)}
      end

      then_ "a Reset to Default button is visible in the White-Label Branding section", context do
        assert has_element?(context.view, "[data-role='reset-white-label']")
        :ok
      end
    end

    scenario "clicking Reset to Default clears custom branding and shows confirmation" do
      given_ :user_logged_in_as_owner

      given_ "the owner has saved custom branding settings", context do
        {:ok, view, _html} = live(context.owner_conn, "/accounts/settings")

        view
        |> form("#white-label-form", white_label: %{
          logo_url: "https://cdn.example.com/logo.png",
          subdomain: "reset-#{System.unique_integer([:positive])}",
          primary_color: "#FF5733",
          secondary_color: "#3498DB"
        })
        |> render_submit()

        {:ok, Map.put(context, :view, view)}
      end

      when_ "the owner clicks the Reset to Default button", context do
        context.view
        |> element("[data-role='reset-white-label']")
        |> render_click()

        {:ok, context}
      end

      then_ "a confirmation message is shown that branding has been reset", context do
        assert render(context.view) =~ "Branding reset to default"
        :ok
      end
    end

    scenario "after resetting branding the white-label form fields are empty" do
      given_ :user_logged_in_as_owner

      given_ "the owner has saved custom branding settings", context do
        {:ok, view, _html} = live(context.owner_conn, "/accounts/settings")
        subdomain = "resetcheck-#{System.unique_integer([:positive])}"

        view
        |> form("#white-label-form", white_label: %{
          logo_url: "https://cdn.example.com/logo.png",
          subdomain: subdomain,
          primary_color: "#FF5733",
          secondary_color: "#3498DB"
        })
        |> render_submit()

        {:ok, context |> Map.put(:view, view) |> Map.put(:subdomain, subdomain)}
      end

      when_ "the owner clicks the Reset to Default button", context do
        context.view
        |> element("[data-role='reset-white-label']")
        |> render_click()

        {:ok, context}
      end

      then_ "the logo URL field is empty", context do
        html = render(context.view)
        refute html =~ "https://cdn.example.com/logo.png"
        :ok
      end

      then_ "the subdomain field is empty", context do
        html = render(context.view)
        refute html =~ context.subdomain
        :ok
      end

      then_ "the color fields are empty", context do
        html = render(context.view)
        refute html =~ "#FF5733"
        refute html =~ "#3498DB"
        :ok
      end
    end
  end
end
