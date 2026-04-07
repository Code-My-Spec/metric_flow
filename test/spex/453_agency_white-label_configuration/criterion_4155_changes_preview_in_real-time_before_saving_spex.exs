defmodule MetricFlowSpex.ChangesPreviewInRealTimeBeforeSavingSpex do
  use SexySpex
  use MetricFlowTest.ConnCase
  import Phoenix.LiveViewTest

  import_givens MetricFlowSpex.SharedGivens

  spex "Changes preview in real-time before saving" do
    scenario "changing primary color updates the preview before form is submitted" do
      given_ :user_logged_in_as_owner

      given_ "the owner is on the account settings page", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/accounts/settings")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "the owner changes the primary color field without submitting", context do
        view = context.view

        view
        |> form("#white-label-form", white_label: %{
          primary_color: "#E74C3C"
        })
        |> render_change()

        {:ok, context}
      end

      then_ "the preview section reflects the new primary color before saving", context do
        html = render(context.view)
        assert html =~ "#E74C3C"
        :ok
      end

      then_ "the white-label form has not been submitted yet", context do
        refute render(context.view) =~ "White-label settings saved"
        :ok
      end
    end

    scenario "changing secondary color updates the preview before form is submitted" do
      given_ :user_logged_in_as_owner

      given_ "the owner is on the account settings page", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/accounts/settings")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "the owner changes the secondary color field without submitting", context do
        view = context.view

        view
        |> form("#white-label-form", white_label: %{
          secondary_color: "#2ECC71"
        })
        |> render_change()

        {:ok, context}
      end

      then_ "the preview section reflects the new secondary color before saving", context do
        html = render(context.view)
        assert html =~ "#2ECC71"
        :ok
      end

      then_ "the white-label form has not been submitted yet", context do
        refute render(context.view) =~ "White-label settings saved"
        :ok
      end
    end

    scenario "changing both primary and secondary colors updates the preview simultaneously" do
      given_ :user_logged_in_as_owner

      given_ "the owner is on the account settings page", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/accounts/settings")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "the owner changes both color fields without submitting", context do
        view = context.view

        view
        |> form("#white-label-form", white_label: %{
          primary_color: "#9B59B6",
          secondary_color: "#F39C12"
        })
        |> render_change()

        {:ok, context}
      end

      then_ "the preview reflects the new primary color", context do
        assert render(context.view) =~ "#9B59B6"
        :ok
      end

      then_ "the preview reflects the new secondary color", context do
        assert render(context.view) =~ "#F39C12"
        :ok
      end

      then_ "the form has not been saved", context do
        refute render(context.view) =~ "White-label settings saved"
        :ok
      end
    end

    scenario "preview updates on every keystroke as the user types a color value" do
      given_ :user_logged_in_as_owner

      given_ "the owner is on the account settings page", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/accounts/settings")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "the owner partially types a color value in the primary color field", context do
        view = context.view

        view
        |> form("#white-label-form", white_label: %{
          primary_color: "#1A"
        })
        |> render_change()

        {:ok, context}
      end

      then_ "the partial color value is visible in the preview area", context do
        assert render(context.view) =~ "#1A"
        :ok
      end

      when_ "the owner completes typing the full color value", context do
        view = context.view

        view
        |> form("#white-label-form", white_label: %{
          primary_color: "#1ABC9C"
        })
        |> render_change()

        {:ok, context}
      end

      then_ "the complete color value is reflected in the preview", context do
        assert render(context.view) =~ "#1ABC9C"
        :ok
      end
    end
  end
end
