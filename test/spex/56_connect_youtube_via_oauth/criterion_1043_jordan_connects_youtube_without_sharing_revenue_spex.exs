defmodule MetricFlowSpex.Story56.Criterion1043Spex do
  @moduledoc """
  Story 56, criterion 1043: declining revenue permission does not prevent
  saving a channel connection, but the user is warned about revenue syncing.
  """

  use MetricFlowSpex.Case
  import MetricFlowSpex.SharedGivens

  spex "Jordan connects YouTube without sharing revenue", criterion: 1043 do
    scenario "channel access is saved while missing revenue permission is explained" do
      given_(:user_logged_in_as_owner)

      given_ "Jordan starts connecting YouTube and declines the revenue permission", context do
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
          youtube: MetricFlowTest.YouTubeNoRevenueOAuthProvider
        })

        Application.put_env(:metric_flow, :req_http_options,
          plug: &MetricFlowTest.YouTubeNoRevenueOAuthProvider.respond/1
        )

        request = get(context.owner_conn, ~p"/app/integrations/oauth/youtube")

        params =
          request |> redirected_to() |> URI.parse() |> Map.fetch!(:query) |> URI.decode_query()

        {:ok,
         Map.merge(context, %{
           oauth_conn: recycle(request),
           oauth_state: Map.fetch!(params, "state")
         })}
      end

      when_ "Jordan finishes signing in and selects a channel", context do
        callback =
          get(context.oauth_conn, ~p"/app/integrations/oauth/callback/youtube", %{
            "code" => "synthetic-no-revenue-code",
            "state" => context.oauth_state
          })

        conn = recycle(callback)
        {:ok, selection, _html} = live(conn, redirected_to(callback))

        selection
        |> form("[data-role='account-selection']", %{"channel_ids" => ["UC_dana_personal"]})
        |> render_submit()

        {:ok, Map.put(context, :conn, conn)}
      end

      then_ "the YouTube integration and selected channel are saved", context do
        {:ok, integrations, _html} = live(context.conn, ~p"/app/integrations")

        assert has_element?(
                 integrations,
                 "[data-role='integration-card'][data-platform='youtube'][data-status='connected']"
               )

        {:ok, selection, _html} =
          live(context.conn, ~p"/app/integrations/connect/youtube/accounts")

        assert has_element?(
                 selection,
                 "[data-role='account-checkbox'][value='UC_dana_personal']:checked"
               )

        {:ok, Map.put(context, :saved_selection, selection)}
      end

      then_ "Jordan is told revenue will not sync until revenue permission is granted", context do
        assert has_element?(
                 context.saved_selection,
                 "[role='alert']",
                 ~r/revenue.*(will not|won't|cannot|can't).*sync/i
               )

        assert has_element?(context.saved_selection, "[role='alert']", ~r/revenue permission/i)
        {:ok, context}
      end
    end
  end
end
