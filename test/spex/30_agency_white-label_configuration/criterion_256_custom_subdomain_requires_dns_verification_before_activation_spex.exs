defmodule MetricFlowSpex.CustomSubdomainRequiresDnsVerificationBeforeActivationSpex do
  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest

  import MetricFlowSpex.SharedGivens

  spex "Custom subdomain requires DNS verification before activation", criterion: 256 do
    scenario "after saving a custom subdomain the user sees DNS verification instructions" do
      given_(:agency_owner_logged_in)

      given_ "the owner navigates to account settings", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/accounts/settings")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "the owner submits the white-label form with a custom subdomain", context do
        context.view
        |> form("#white-label-form",
          white_label: %{
            subdomain: "reports-myagency",
            logo_url: "",
            primary_color: "#3B82F6",
            secondary_color: "#1E40AF"
          }
        )
        |> render_submit()

        {:ok, context}
      end

      then_ "DNS verification instructions are visible on the page", context do
        html = render(context.view)
        assert html =~ "DNS"
        {:ok, context}
      end

      then_ "the user sees guidance on how to point the subdomain", context do
        html = render(context.view)
        assert html =~ "reports-myagency"
        assert html =~ "verif"
        {:ok, context}
      end
    end

    scenario "a newly saved subdomain shows a pending verification status before DNS is confirmed" do
      given_(:agency_owner_logged_in)

      given_ "the owner navigates to account settings", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/accounts/settings")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "the owner submits the white-label form with a new subdomain", context do
        context.view
        |> form("#white-label-form",
          white_label: %{
            subdomain: "pending-subdomain",
            logo_url: "",
            primary_color: "#1A2B3C",
            secondary_color: "#4D5E6F"
          }
        )
        |> render_submit()

        {:ok, context}
      end

      then_ "the subdomain status is shown as pending verification", context do
        html = render(context.view)

        assert html =~ "Pending" or html =~ "pending" or html =~ "unverified" or
                 html =~ "Unverified" or html =~ "not active" or html =~ "Not active"

        {:ok, context}
      end

      then_ "the subdomain is not shown as active", context do
        html = render(context.view)
        refute html =~ "Active" and html =~ "pending-subdomain"
        {:ok, context}
      end
    end

    scenario "the settings page shows a Verify DNS button or mechanism to check verification status" do
      given_(:agency_owner_logged_in)

      given_ "the owner navigates to account settings and saves a subdomain", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/accounts/settings")

        view
        |> form("#white-label-form",
          white_label: %{
            subdomain: "verify-test",
            logo_url: "",
            primary_color: "#3B82F6",
            secondary_color: "#1E40AF"
          }
        )
        |> render_submit()

        {:ok, Map.put(context, :view, view)}
      end

      then_ "a verify DNS button or link is present on the page", context do
        html = render(context.view)

        assert html =~ "Verify" or html =~ "verify" or
                 has_element?(context.view, "[data-role='verify-dns']") or
                 has_element?(context.view, "button", "Verify DNS") or
                 has_element?(context.view, "a", "Verify DNS")

        {:ok, context}
      end
    end
  end
end
