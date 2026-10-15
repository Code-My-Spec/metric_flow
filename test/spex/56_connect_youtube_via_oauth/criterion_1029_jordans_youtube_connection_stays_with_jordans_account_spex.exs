defmodule MetricFlowSpex.Story56.Criterion1029Spex do
  @moduledoc """
  Story 56, criterion 1029: agency access does not transfer client ownership
  of a YouTube connection. Setup drives OAuth, selection, and invitations.
  """

  use MetricFlowSpex.Case
  import MetricFlowSpex.SharedGivens
  import Swoosh.TestAssertions

  spex "Jordan's YouTube connection stays with Jordan's account", criterion: 1029 do
    scenario "Alex can view the client's connection but cannot move it to the agency" do
      given_(:user_logged_in_as_owner)

      given_ "Jordan connects YouTube on the client account", context do
        originals =
          for key <- [:oauth_providers, :req_http_options],
              do: {key, Application.fetch_env(:metric_flow, key)}

        on_exit(fn ->
          for {key, value} <- originals do
            case value do
              {:ok, original} -> Application.put_env(:metric_flow, key, original)
              :error -> Application.delete_env(:metric_flow, key)
            end
          end
        end)

        Application.put_env(:metric_flow, :oauth_providers, %{
          youtube: MetricFlowTest.YouTubeOAuthProvider
        })

        Application.put_env(:metric_flow, :req_http_options,
          plug: &MetricFlowTest.YouTubeOAuthProvider.respond/1
        )

        request = get(context.owner_conn, ~p"/app/integrations/oauth/youtube")

        params =
          request |> redirected_to() |> URI.parse() |> Map.fetch!(:query) |> URI.decode_query()

        callback =
          request
          |> recycle()
          |> get(~p"/app/integrations/oauth/callback/youtube", %{
            "code" => "synthetic-youtube-code",
            "state" => Map.fetch!(params, "state")
          })

        conn = recycle(callback)
        {:ok, selection, _html} = live(conn, redirected_to(callback))

        selection
        |> form("[data-role='account-selection']", %{"channel_ids" => ["UC_dana_personal"]})
        |> render_submit()

        {:ok, Map.put(context, :client_conn, conn)}
      end

      given_(:agency_owner_logged_in)

      given_ "Jordan grants Alex's agency access to the client account", context do
        {:ok, invitations, _html} = live(context.client_conn, ~p"/app/accounts/invitations")

        invitations
        |> form("#invite_member_form",
          invitation: %{email: context.owner_email, role: "account_manager"}
        )
        |> render_submit()

        token =
          assert_email_sent(fn email ->
            [_, token] = Regex.run(~r|/invitations/([^\s/]+)|, email.text_body)
            token
          end)

        {:ok, invitation, _html} = live(context.owner_conn, ~p"/invitations/#{token}")
        invitation |> element("[data-role='accept-btn']") |> render_click()

        {:ok, accounts, _html} = live(context.owner_conn, ~p"/app/accounts")

        accounts
        |> element("[data-role='switch-account']", "Switch to Owner Account")
        |> render_click()

        {:ok, context}
      end

      when_ "Alex views the client's integrations", context do
        {:ok, integrations, _html} = live(context.owner_conn, ~p"/app/integrations")
        {:ok, Map.put(context, :integrations, integrations)}
      end

      then_ "the YouTube connection is shown as owned by the client account", context do
        assert has_element?(
                 context.integrations,
                 "[data-role='integration-card'][data-platform='youtube'][data-status='connected']",
                 "Owner Account"
               )

        {:ok, context}
      end

      then_ "Alex cannot move the connection to the agency", context do
        card = "[data-role='integration-card'][data-platform='youtube']"
        assert has_element?(context.integrations, card)
        refute has_element?(context.integrations, card <> " button", ~r/move|transfer/i)
        refute has_element?(context.integrations, card <> " a", ~r/move|transfer/i)
        refute has_element?(context.integrations, card <> " select[name='account_id']")

        {:ok, accounts, _html} = live(context.owner_conn, ~p"/app/accounts")

        accounts
        |> element("[data-role='switch-account']", "Switch to Agency Owner Account")
        |> render_click()

        {:ok, agency, _html} = live(context.owner_conn, ~p"/app/integrations")
        assert has_element?(agency, "[data-role='integrations-index']")
        refute has_element?(agency, card)

        {:ok, client, _html} = live(context.client_conn, ~p"/app/integrations")
        assert has_element?(client, card <> "[data-status='connected']")
        {:ok, context}
      end
    end
  end
end
