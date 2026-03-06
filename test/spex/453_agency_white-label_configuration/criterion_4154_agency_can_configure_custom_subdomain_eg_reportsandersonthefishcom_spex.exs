defmodule MetricFlowSpex.AgencyCanConfigureCustomSubdomainEgReportsandersonthefishcomSpex do
  use SexySpex
  use MetricFlowTest.ConnCase
  import Phoenix.LiveViewTest

  import_givens MetricFlowSpex.SharedGivens

  spex "Agency can configure custom subdomain (e.g., reports.andersonthefish.com)" do
    scenario "agency settings page shows a custom subdomain input field" do
      given_ :user_logged_in_as_owner

      given_ "the owner navigates to account settings", context do
        {:ok, view, _html} = live(context.owner_conn, "/accounts/settings")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "the White-Label Branding section is visible", context do
        assert render(context.view) =~ "White-Label Branding"
        :ok
      end

      then_ "a Subdomain input field is present in the white-label form", context do
        assert has_element?(context.view, "#white-label-form input[name='white_label[subdomain]']")
        :ok
      end

      then_ "helper text describes the subdomain format requirements", context do
        assert render(context.view) =~ "Lowercase letters, numbers, and hyphens only"
        :ok
      end
    end

    scenario "agency owner can enter and save a custom subdomain" do
      given_ :user_logged_in_as_owner

      given_ "the owner navigates to account settings", context do
        {:ok, view, _html} = live(context.owner_conn, "/accounts/settings")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "the owner submits the white-label form with a custom subdomain", context do
        context.view
        |> form("#white-label-form", white_label: %{
          subdomain: "reports-andersonthefish",
          logo_url: "",
          primary_color: "#3B82F6",
          secondary_color: "#1E40AF"
        })
        |> render_submit()

        {:ok, context}
      end

      then_ "a success confirmation message is shown", context do
        assert render(context.view) =~ "White-label settings saved"
        :ok
      end

      then_ "the saved subdomain is reflected in the rendered page", context do
        assert render(context.view) =~ "reports-andersonthefish"
        :ok
      end
    end

    scenario "saved subdomain is visible when the settings page is revisited" do
      given_ :user_logged_in_as_owner

      given_ "the owner navigates to account settings and saves a subdomain", context do
        {:ok, view, _html} = live(context.owner_conn, "/accounts/settings")

        view
        |> form("#white-label-form", white_label: %{
          subdomain: "andersonthefish",
          logo_url: "",
          primary_color: "#3B82F6",
          secondary_color: "#1E40AF"
        })
        |> render_submit()

        {:ok, context}
      end

      given_ "the owner navigates away and returns to account settings", context do
        {:ok, fresh_view, _html} = live(context.owner_conn, "/accounts/settings")
        {:ok, Map.put(context, :view, fresh_view)}
      end

      then_ "the previously saved subdomain is pre-filled in the subdomain input", context do
        assert has_element?(
          context.view,
          "#white-label-form input[name='white_label[subdomain]'][value='andersonthefish']"
        )
        :ok
      end
    end
  end
end
