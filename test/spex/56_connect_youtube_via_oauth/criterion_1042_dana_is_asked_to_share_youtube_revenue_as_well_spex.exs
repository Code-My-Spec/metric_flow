defmodule MetricFlowSpex.Story56.Criterion1042Spex do
  @moduledoc """
  Story 56, criterion 1042: consent includes read-only YouTube revenue access.
  Observes the real application's authorization URL, without a stub provider.
  """

  use MetricFlowSpex.Case
  import MetricFlowSpex.SharedGivens

  spex "Dana is asked to share YouTube revenue as well", criterion: 1042 do
    scenario "Google requests channel, analytics, and revenue read access only" do
      given_(:user_logged_in_as_owner)

      given_ "Dana is choosing a platform to connect", context do
        {:ok, view, _html} = live(context.owner_conn, ~p"/app/integrations/connect")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "Dana starts connecting YouTube", context do
        context.view
        |> element("[data-platform='youtube'] [data-role='connect-button']")
        |> render_click()

        {:ok, context}
      end

      then_ "Google consent requests all three read-only permissions and no video write access",
            context do
        {path, _flash} = assert_redirect(context.view)
        assert path == ~p"/app/integrations/oauth/youtube"
        response = get(context.owner_conn, path)
        uri = response |> redirected_to() |> URI.parse()
        assert uri.scheme == "https"
        assert uri.host == "accounts.google.com"

        params = URI.decode_query(uri.query || "")
        scopes = MapSet.new(String.split(params["scope"] || ""))

        required =
          MapSet.new([
            "https://www.googleapis.com/auth/youtube.readonly",
            "https://www.googleapis.com/auth/yt-analytics.readonly",
            "https://www.googleapis.com/auth/yt-analytics-monetary.readonly"
          ])

        assert MapSet.subset?(required, scopes)

        youtube_scopes =
          scopes
          |> Enum.filter(fn scope ->
            String.starts_with?(scope, "https://www.googleapis.com/auth/youtube") or
              String.starts_with?(scope, "https://www.googleapis.com/auth/yt-analytics")
          end)
          |> MapSet.new()

        assert youtube_scopes == required
        {:ok, context}
      end
    end
  end
end
