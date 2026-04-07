defmodule MetricFlowSpex.CorrelationAccessFromMainNavigationSpex do
  use SexySpex
  use MetricFlowTest.ConnCase
  import Phoenix.LiveViewTest

  import_givens MetricFlowSpex.SharedGivens

  spex "User can access correlation analysis from main navigation" do
    scenario "authenticated user sees a Correlations link in the main navigation" do
      given_ :user_logged_in_as_owner
      given_ :owner_has_active_subscription

      given_ "the user is on any authenticated page", context do
        {:ok, view, _html} = live(context.owner_conn, "/dashboard")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "the navigation contains a link to the Correlations page", context do
        html = render(context.view)

        assert html =~ "Correlations",
               "Expected the navigation to contain a 'Correlations' link. Got: #{html}"

        :ok
      end
    end

    scenario "authenticated user can navigate to the Correlations page via the navigation link" do
      given_ :user_logged_in_as_owner
      given_ :owner_has_active_subscription

      given_ "the user navigates to the correlations page", context do
        {:ok, view, _html} = live(context.owner_conn, "/correlations")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "the correlations page is displayed", context do
        html = render(context.view)

        assert html =~ "Correlations",
               "Expected the correlations page to be displayed with a heading. Got: #{html}"

        :ok
      end
    end

    scenario "unauthenticated user is redirected when accessing correlations" do
      given_ "an unauthenticated user tries to access the correlations page", _context do
        conn = build_conn()
        {:ok, Map.put(%{}, :conn, conn)}
      end

      when_ "the user visits the correlations page directly", context do
        result =
          try do
            live(context.conn, "/correlations")
          rescue
            e -> {:error, e}
          end

        {:ok, Map.put(context, :result, result)}
      end

      then_ "the user is not granted access to the correlations page", context do
        case context.result do
          {:error, {:redirect, %{to: path}}} ->
            assert path =~ "log-in",
                   "Expected redirect to login page, got: #{path}"

          {:ok, _view, html} ->
            refute html =~ "Which metrics drive your goal",
                   "Expected unauthenticated user to not see the correlations page content"
        end

        :ok
      end
    end
  end
end
