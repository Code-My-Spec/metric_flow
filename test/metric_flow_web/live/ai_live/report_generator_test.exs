defmodule MetricFlowWeb.AiLive.ReportGeneratorTest do
  use MetricFlowTest.ConnCase, async: false

  import ExUnit.CaptureLog
  import Phoenix.LiveViewTest
  import MetricFlowTest.UsersFixtures
  import ReqCassette

  alias MetricFlow.Dashboards.Visualization
  alias MetricFlow.Repo

  @cassette_dir "test/cassettes/ai"
  @filter_headers [filter_request_headers: ["x-api-key", "authorization"]]

  # ---------------------------------------------------------------------------
  # ReqCassette helpers
  #
  # The LiveView reads Application.get_env(:metric_flow, :req_http_options, [])
  # and passes it through to Ai.generate_vega_spec/3. We set the plug from
  # ReqCassette's with_cassette so real API calls are recorded/replayed.
  # ---------------------------------------------------------------------------

  defp setup_cassette_plug(plug) do
    Application.put_env(:metric_flow, :req_http_options, plug: plug)

    ExUnit.Callbacks.on_exit(fn ->
      Application.delete_env(:metric_flow, :req_http_options)
    end)
  end

  # ---------------------------------------------------------------------------
  # Fixtures
  # ---------------------------------------------------------------------------

  defp mount_report_generator(conn, user) do
    conn = log_in_user(conn, user)
    live(conn, ~p"/reports/generate")
  end

  # ---------------------------------------------------------------------------
  # describe "mount/3"
  # ---------------------------------------------------------------------------

  describe "mount/3" do
    test "renders the Generate Report page for an authenticated user", %{conn: conn} do
      user = user_fixture()

      capture_log(fn ->
        {:ok, _lv, html} = mount_report_generator(conn, user)
        assert html =~ "Generate Report"
      end)
    end

    test "renders the prompt form with textarea and generate button", %{conn: conn} do
      user = user_fixture()

      capture_log(fn ->
        {:ok, lv, _html} = mount_report_generator(conn, user)

        assert has_element?(lv, "[data-role='prompt-form']")
        assert has_element?(lv, "[data-role='prompt-input']")
        assert has_element?(lv, "[data-role='generate-btn']")
      end)
    end

    test "generate button is disabled on mount when prompt is blank", %{conn: conn} do
      user = user_fixture()

      capture_log(fn ->
        {:ok, lv, _html} = mount_report_generator(conn, user)
        assert has_element?(lv, "[data-role='generate-btn'][disabled]")
      end)
    end

    test "shows the empty state on initial load", %{conn: conn} do
      user = user_fixture()

      capture_log(fn ->
        {:ok, lv, _html} = mount_report_generator(conn, user)
        assert has_element?(lv, "[data-role='empty-state']")
      end)
    end

    test "does not show chart preview or save sections on mount", %{conn: conn} do
      user = user_fixture()

      capture_log(fn ->
        {:ok, lv, _html} = mount_report_generator(conn, user)

        refute has_element?(lv, "[data-role='chart-preview-section']")
        refute has_element?(lv, "[data-role='save-section']")
        refute has_element?(lv, "[data-role='save-confirmation']")
      end)
    end

    test "redirects unauthenticated users to /users/log-in", %{conn: conn} do
      assert {:error, {:redirect, %{to: "/users/log-in"}}} =
               live(conn, ~p"/reports/generate")
    end
  end

  # ---------------------------------------------------------------------------
  # describe "handle_event update_prompt"
  # ---------------------------------------------------------------------------

  describe "handle_event update_prompt" do
    test "updates the prompt and enables the generate button", %{conn: conn} do
      user = user_fixture()

      capture_log(fn ->
        {:ok, lv, _html} = mount_report_generator(conn, user)

        html = render_change(lv, "update_prompt", %{"prompt" => "Show weekly revenue"})
        assert html =~ "Show weekly revenue"
        refute has_element?(lv, "[data-role='generate-btn'][disabled]")
      end)
    end

    test "generate button remains disabled when prompt is only whitespace", %{conn: conn} do
      user = user_fixture()

      capture_log(fn ->
        {:ok, lv, _html} = mount_report_generator(conn, user)

        render_change(lv, "update_prompt", %{"prompt" => "   "})
        assert has_element?(lv, "[data-role='generate-btn'][disabled]")
      end)
    end
  end

  # ---------------------------------------------------------------------------
  # describe "handle_event generate" — real API via ReqCassette
  # ---------------------------------------------------------------------------

  describe "handle_event generate" do
    test "shows chart preview and save section after successful generation", %{conn: conn} do
      user = user_fixture()

      with_cassette "report_generator_success", [cassette_dir: @cassette_dir] ++ @filter_headers, fn plug ->
        setup_cassette_plug(plug)

        capture_log(fn ->
          {:ok, lv, _html} = mount_report_generator(conn, user)

          render_change(lv, "update_prompt", %{"prompt" => "Show weekly revenue"})
          render_submit(lv, "generate", %{"prompt" => "Show weekly revenue"})

          assert has_element?(lv, "[data-role='chart-preview-section']")
          assert has_element?(lv, "[data-role='save-section']")
          refute has_element?(lv, "[data-role='empty-state']")
        end)
      end
    end

    test "vega-lite chart container carries the encoded spec", %{conn: conn} do
      user = user_fixture()

      with_cassette "report_generator_success", [cassette_dir: @cassette_dir] ++ @filter_headers, fn plug ->
        setup_cassette_plug(plug)

        capture_log(fn ->
          {:ok, lv, _html} = mount_report_generator(conn, user)

          render_change(lv, "update_prompt", %{"prompt" => "Show weekly revenue"})
          render_submit(lv, "generate", %{"prompt" => "Show weekly revenue"})

          html = render(lv)
          assert html =~ "vega-lite"
        end)
      end
    end

    test "shows error message when API call fails", %{conn: conn} do
      user = user_fixture()

      with_cassette "report_generator_error", [cassette_dir: @cassette_dir, match_requests_on: [:method, :uri]] ++ @filter_headers, fn plug ->
        setup_cassette_plug(plug)

        capture_log(fn ->
          {:ok, lv, _html} = mount_report_generator(conn, user)

          render_change(lv, "update_prompt", %{"prompt" => "Show revenue"})
          render_submit(lv, "generate", %{"prompt" => "Show revenue"})

          assert has_element?(lv, "[data-role='generate-error']")
          refute has_element?(lv, "[data-role='chart-preview-section']")
        end)
      end
    end

    test "ignores generate when the prompt is blank", %{conn: conn} do
      user = user_fixture()

      capture_log(fn ->
        {:ok, lv, _html} = mount_report_generator(conn, user)

        render_submit(lv, "generate", %{"prompt" => "   "})

        refute has_element?(lv, "[data-role='chart-preview-section']")
        assert has_element?(lv, "[data-role='empty-state']")
      end)
    end
  end

  # ---------------------------------------------------------------------------
  # describe "handle_event save_visualization"
  # ---------------------------------------------------------------------------

  describe "handle_event save_visualization" do
    test "saves the visualization and shows confirmation", %{conn: conn} do
      user = user_fixture()

      with_cassette "report_generator_success", [cassette_dir: @cassette_dir] ++ @filter_headers, fn plug ->
        setup_cassette_plug(plug)

        capture_log(fn ->
          {:ok, lv, _html} = mount_report_generator(conn, user)

          render_change(lv, "update_prompt", %{"prompt" => "Show weekly revenue"})
          render_submit(lv, "generate", %{"prompt" => "Show weekly revenue"})
          render_change(lv, "update_save_name", %{"save_name" => "Weekly Revenue"})
          render_click(lv, "save_visualization", %{})

          assert has_element?(lv, "[data-role='save-confirmation']")
          refute has_element?(lv, "[data-role='save-section']")
          assert Repo.get_by(Visualization, name: "Weekly Revenue") != nil
        end)
      end
    end

    test "shows save error when name is blank", %{conn: conn} do
      user = user_fixture()

      with_cassette "report_generator_success", [cassette_dir: @cassette_dir] ++ @filter_headers, fn plug ->
        setup_cassette_plug(plug)

        capture_log(fn ->
          {:ok, lv, _html} = mount_report_generator(conn, user)

          render_change(lv, "update_prompt", %{"prompt" => "Show weekly revenue"})
          render_submit(lv, "generate", %{"prompt" => "Show weekly revenue"})
          render_click(lv, "save_visualization", %{})

          assert has_element?(lv, "[data-role='save-error']")
          refute has_element?(lv, "[data-role='save-confirmation']")
        end)
      end
    end
  end

  # ---------------------------------------------------------------------------
  # describe "handle_event generate_another"
  # ---------------------------------------------------------------------------

  describe "handle_event generate_another" do
    test "resets the page to the initial empty state", %{conn: conn} do
      user = user_fixture()

      with_cassette "report_generator_success", [cassette_dir: @cassette_dir] ++ @filter_headers, fn plug ->
        setup_cassette_plug(plug)

        capture_log(fn ->
          {:ok, lv, _html} = mount_report_generator(conn, user)

          render_change(lv, "update_prompt", %{"prompt" => "Show weekly revenue"})
          render_submit(lv, "generate", %{"prompt" => "Show weekly revenue"})
          render_change(lv, "update_save_name", %{"save_name" => "Weekly Revenue"})
          render_click(lv, "save_visualization", %{})

          lv
          |> element("[data-role='save-confirmation'] button", "Generate Another")
          |> render_click()

          assert has_element?(lv, "[data-role='empty-state']")
          refute has_element?(lv, "[data-role='chart-preview-section']")
          refute has_element?(lv, "[data-role='save-confirmation']")
        end)
      end
    end
  end
end
