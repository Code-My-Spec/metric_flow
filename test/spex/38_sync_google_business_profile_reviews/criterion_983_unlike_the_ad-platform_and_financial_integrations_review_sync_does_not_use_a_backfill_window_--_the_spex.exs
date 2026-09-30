defmodule MetricFlowSpex.Criterion983ReviewSyncHasNoBackfillWindowSpex do
  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest

  import MetricFlowSpex.SharedGivens

  spex "Unlike the ad-platform and financial integrations, review sync does not use a backfill window",
       criterion: 983 do
    scenario "a Google Business Profile location's first review sync is not marked as an initial backfill" do
      given_ :user_logged_in_as_owner

      given_ "a Google Business Profile location has never synced reviews before", context do
        MetricFlowSpex.Fixtures.create_integration_for(context.owner_email, :google_business_reviews,
          provider_metadata: %{"included_locations" => ["locations/123456789"]}
        )

        {:ok, context}
      end

      when_ "the first sync runs", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/integrations/sync-history")
        view |> element("[data-role='trigger-daily-sync']") |> render_click()
        Oban.drain_queue(queue: :sync)
        {:ok, Map.put(context, :view, view)}
      end

      then_ "the reviews entry completes successfully without an Initial Sync backfill marker, since the full history is retrieved every time", context do
        assert has_element?(
                 context.view,
                 "[data-role='sync-history-entry'][data-status='success'] [data-role='sync-provider']",
                 "Google Business Reviews"
               )

        # A compound selector like "[data-sync-type='initial'] [data-role='sync-provider']"
        # can never distinguish entries: data-sync-type is on an inner badge span,
        # data-role='sync-provider' is a separate sibling span, and this integration's
        # single sync produces two entries (performance + reviews) -- one of which
        # legitimately does carry the Initial Sync badge. Scope to the reviews entry
        # itself via Floki rather than a single CSS selector.
        reviews_entries =
          context.view
          |> render()
          |> Floki.parse_document!()
          |> Floki.find("[data-role='sync-history-entry']")
          |> Enum.filter(fn entry ->
            entry
            |> Floki.find("[data-role='sync-provider']")
            |> Floki.text()
            |> String.contains?("Google Business Reviews")
          end)

        assert reviews_entries != []

        assert Enum.all?(reviews_entries, fn entry ->
                 Floki.find(entry, "[data-sync-type='initial']") == []
               end)

        {:ok, context}
      end
    end
  end
end
