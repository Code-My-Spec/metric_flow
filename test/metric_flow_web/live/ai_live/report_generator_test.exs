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
  # ---------------------------------------------------------------------------

  defp setup_cassette_plug(plug) do
    Application.put_env(:metric_flow, :req_http_options, plug: plug)

    ExUnit.Callbacks.on_exit(fn ->
      Application.delete_env(:metric_flow, :req_http_options)
    end)
  end

  defp mount_report_generator(conn, user) do
    conn = log_in_user(conn, user)
    live(conn, ~p"/app/reports/generate")
  end

  # ---------------------------------------------------------------------------
  # Test Assertions from spec
  # ---------------------------------------------------------------------------

  describe "renders report generator page with prompt form and Generate Chart button" do
    test "renders report generator page with prompt form and Generate Chart button", %{conn: conn} do
      user = user_fixture()

      capture_log(fn ->
        {:ok, lv, html} = mount_report_generator(conn, user)

        assert html =~ "Generate Report"
        assert has_element?(lv, "[data-role='prompt-form']")
        assert has_element?(lv, "[data-role='prompt-input']")
        assert has_element?(lv, "[data-role='generate-btn']")
      end)
    end
  end

  describe "shows empty state when no chart has been generated" do
    test "shows empty state when no chart has been generated", %{conn: conn} do
      user = user_fixture()

      capture_log(fn ->
        {:ok, lv, _html} = mount_report_generator(conn, user)

        assert has_element?(lv, "[data-role='empty-state']")
        refute has_element?(lv, "[data-role='chart-preview-section']")
        refute has_element?(lv, "[data-role='save-section']")
        refute has_element?(lv, "[data-role='save-confirmation']")
      end)
    end
  end

  describe "updates prompt text on change without calling any context" do
    test "updates prompt text on change without calling any context", %{conn: conn} do
      user = user_fixture()

      capture_log(fn ->
        {:ok, lv, _html} = mount_report_generator(conn, user)

        html = render_change(lv, "update_prompt", %{"prompt" => "Show weekly revenue"})
        assert html =~ "Show weekly revenue"
        refute has_element?(lv, "[data-role='generate-btn'][disabled]")
      end)
    end
  end

  describe "disables generate button when prompt is blank or generation is in progress" do
    test "disables generate button when prompt is blank or generation is in progress", %{conn: conn} do
      user = user_fixture()

      capture_log(fn ->
        {:ok, lv, _html} = mount_report_generator(conn, user)
        assert has_element?(lv, "[data-role='generate-btn'][disabled]")
      end)
    end
  end

  describe "shows chart preview section with Vega-Lite container after successful generation" do
    test "shows chart preview section with Vega-Lite container after successful generation", %{conn: conn} do
      user = user_fixture()

      with_cassette "report_generator_success", [cassette_dir: @cassette_dir] ++ @filter_headers, fn plug ->
        setup_cassette_plug(plug)

        capture_log(fn ->
          {:ok, lv, _html} = mount_report_generator(conn, user)

          render_change(lv, "update_prompt", %{"prompt" => "Show weekly revenue"})
          render_submit(lv, "generate", %{"prompt" => "Show weekly revenue"})

          assert has_element?(lv, "[data-role='chart-preview-section']")
          assert render(lv) =~ "vega-lite"
          refute has_element?(lv, "[data-role='empty-state']")
        end)
      end
    end
  end

  describe "shows error message when generation fails" do
    test "shows error message when generation fails", %{conn: conn} do
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
  end

  describe "shows save section with name input after chart is generated" do
    test "shows save section with name input after chart is generated", %{conn: conn} do
      user = user_fixture()

      with_cassette "report_generator_success", [cassette_dir: @cassette_dir] ++ @filter_headers, fn plug ->
        setup_cassette_plug(plug)

        capture_log(fn ->
          {:ok, lv, _html} = mount_report_generator(conn, user)

          render_change(lv, "update_prompt", %{"prompt" => "Show weekly revenue"})
          render_submit(lv, "generate", %{"prompt" => "Show weekly revenue"})

          assert has_element?(lv, "[data-role='save-section']")
          assert has_element?(lv, "[data-role='save-name-input']")
        end)
      end
    end
  end

  describe "saves visualization and shows confirmation with link to visualizations" do
    test "saves visualization and shows confirmation with link to visualizations", %{conn: conn} do
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
  end

  describe "shows save error when save name is blank" do
    test "shows save error when save name is blank", %{conn: conn} do
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

  describe "disables save button when vega_spec is nil or save name is blank" do
    test "disables save button when vega_spec is nil or save name is blank", %{conn: conn} do
      user = user_fixture()

      capture_log(fn ->
        {:ok, lv, _html} = mount_report_generator(conn, user)

        refute has_element?(lv, "[data-role='save-visualization-btn']")
      end)
    end
  end

  describe "resets state when Generate Another is clicked after saving" do
    test "resets state when Generate Another is clicked after saving", %{conn: conn} do
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
