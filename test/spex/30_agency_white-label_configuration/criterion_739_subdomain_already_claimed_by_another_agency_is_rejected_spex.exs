defmodule MetricFlowSpex.SubdomainAlreadyClaimedByAnotherAgencyIsRejectedSpex do
  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest

  import MetricFlowSpex.SharedGivens

  spex "Subdomain already claimed by another agency is rejected", criterion: 739 do
    scenario "an agency owner cannot configure a subdomain already claimed by another agency" do
      given_(:agency_owner_logged_in)

      given_ "a subdomain is already configured by a different agency", context do
        subdomain = "claimed739-#{System.unique_integer([:positive])}"

        {:ok, first_view, _html} = live(context.owner_conn, "/app/accounts/settings")

        first_view
        |> form("#white-label-form",
          white_label: %{
            subdomain: subdomain,
            primary_color: "#FF5733",
            secondary_color: "#3498DB"
          }
        )
        |> render_submit()

        second_email = "second739-#{System.unique_integer([:positive])}@example.com"
        second_password = "SecurePassword123!"

        reg_conn = build_conn()
        {:ok, reg_view, _html} = live(reg_conn, "/users/register")

        reg_view
        |> form("#registration_form",
          user: %{
            email: second_email,
            password: second_password,
            account_name: "Second Agency 739",
            account_type: "agency"
          }
        )
        |> render_submit()

        {:ok, login_view, _html} = live(build_conn(), "/users/log-in")

        login_form =
          form(login_view, "#login_form_password",
            user: %{email: second_email, password: second_password, remember_me: true}
          )

        second_conn = login_form |> submit_form(build_conn()) |> recycle()

        {:ok, Map.merge(context, %{second_conn: second_conn, subdomain: subdomain})}
      end

      when_ "an agency owner tries to configure that same subdomain", context do
        {:ok, second_view, _html} = live(context.second_conn, "/app/accounts/settings")

        second_view
        |> form("#white-label-form",
          white_label: %{
            subdomain: context.subdomain,
            primary_color: "#111111",
            secondary_color: "#222222"
          }
        )
        |> render_submit()

        {:ok, Map.put(context, :second_view, second_view)}
      end

      then_ "the configuration is rejected as already in use", context do
        html = render(context.second_view)

        assert html =~ "has already been taken",
               "Expected a rejection explaining the subdomain is already claimed, got: #{html}"

        {:ok, context}
      end
    end
  end
end
