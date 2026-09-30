defmodule MetricFlowSpex.Criterion740ChangesPreviewInRealTimeBeforeSavingSpex do
  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest

  import MetricFlowSpex.SharedGivens

  spex "Changes preview in real time before saving", criterion: 740 do
    scenario "a live preview updates immediately as the agency owner edits colors, without saving" do
      given_(:agency_owner_logged_in)

      given_ "the agency owner is editing logo or color settings", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/accounts/settings")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "they make a change", context do
        context.view
        |> form("#white-label-form",
          white_label: %{primary_color: "#ABCDEF", secondary_color: "#123456"}
        )
        |> render_change()

        {:ok, context}
      end

      then_ "a live preview updates immediately without requiring a save", context do
        assert has_element?(context.view, "[data-role='white-label-preview']")
        html = render(context.view)
        assert html =~ "#ABCDEF"
        assert html =~ "#123456"
        refute html =~ "White-label settings saved"
        {:ok, context}
      end
    end
  end
end
