defmodule MetricFlow.Ai.ReportGeneratorTest do
  use ExUnit.Case, async: true

  alias MetricFlow.Ai.ReportGenerator
  alias MetricFlowTest.ClaudeCodeStub

  # ---------------------------------------------------------------------------
  # Fixtures
  # ---------------------------------------------------------------------------

  defp user_prompt, do: "Show me a bar chart of revenue over time"

  defp metric_names, do: ["revenue", "sessions", "ad_spend"]

  defp vega_spec(overrides \\ %{}) do
    Map.merge(
      %{
        "$schema" => "https://vega.github.io/schema/vega-lite/v5.json",
        "mark" => "bar",
        "encoding" => %{
          "x" => %{"field" => "date", "type" => "temporal", "title" => "Date"},
          "y" => %{"field" => "revenue", "type" => "quantitative", "title" => "Revenue"}
        },
        "title" => "Revenue Over Time"
      },
      overrides
    )
  end

  # ---------------------------------------------------------------------------
  # build_system_prompt/0 — pure function
  # ---------------------------------------------------------------------------

  describe "build_system_prompt/0" do
    test "includes base marketing analytics context" do
      prompt = ReportGenerator.build_system_prompt()

      assert String.downcase(prompt) =~ ~r/marketing|analytics|metric/
    end

    test "includes Vega-Lite task-specific instructions" do
      prompt = ReportGenerator.build_system_prompt()

      assert String.downcase(prompt) =~ ~r/vega|chart|visualization|spec/
    end

    test "returns a non-empty string" do
      prompt = ReportGenerator.build_system_prompt()

      assert is_binary(prompt)
      assert String.length(prompt) > 20
    end
  end

  # ---------------------------------------------------------------------------
  # build_user_content/2 — pure function
  # ---------------------------------------------------------------------------

  describe "build_user_content/2" do
    test "includes the user prompt" do
      content = ReportGenerator.build_user_content(user_prompt(), metric_names())

      assert String.contains?(content, user_prompt())
    end

    test "includes available metric names" do
      content = ReportGenerator.build_user_content(user_prompt(), metric_names())

      assert String.contains?(content, "revenue")
      assert String.contains?(content, "sessions")
      assert String.contains?(content, "ad_spend")
    end

    test "handles empty metric names list" do
      content = ReportGenerator.build_user_content(user_prompt(), [])

      assert is_binary(content)
      assert String.contains?(content, user_prompt())
    end
  end

  # ---------------------------------------------------------------------------
  # generate/3 — integration via Alloy's ClaudeCode command_runner stub
  # ---------------------------------------------------------------------------

  describe "generate/3" do
    test "returns ok tuple with Vega-Lite spec map on success" do
      runner = ClaudeCodeStub.tool_call("emit_vega_spec", %{"spec" => vega_spec()})

      result = ReportGenerator.generate(user_prompt(), metric_names(), command_runner: runner)

      assert {:ok, spec} = result
      assert is_map(spec)
    end

    test "returned map contains dollar-schema key" do
      runner = ClaudeCodeStub.tool_call("emit_vega_spec", %{"spec" => vega_spec()})

      {:ok, spec} = ReportGenerator.generate(user_prompt(), metric_names(), command_runner: runner)

      assert Map.has_key?(spec, "$schema")
    end

    test "returned map contains mark key" do
      runner = ClaudeCodeStub.tool_call("emit_vega_spec", %{"spec" => vega_spec()})

      {:ok, spec} = ReportGenerator.generate(user_prompt(), metric_names(), command_runner: runner)

      assert Map.has_key?(spec, "mark")
    end

    test "returned map contains encoding key" do
      runner = ClaudeCodeStub.tool_call("emit_vega_spec", %{"spec" => vega_spec()})

      {:ok, spec} = ReportGenerator.generate(user_prompt(), metric_names(), command_runner: runner)

      assert Map.has_key?(spec, "encoding")
    end

    test "dollar-schema field points to a Vega-Lite v5 URL" do
      runner = ClaudeCodeStub.tool_call("emit_vega_spec", %{"spec" => vega_spec()})

      {:ok, spec} = ReportGenerator.generate(user_prompt(), metric_names(), command_runner: runner)

      assert String.contains?(spec["$schema"], "vega-lite")
      assert String.contains?(spec["$schema"], "v5")
    end

    test "returns error tuple when API call fails" do
      runner = ClaudeCodeStub.error("simulated provider failure")

      result = ReportGenerator.generate(user_prompt(), metric_names(), command_runner: runner)

      assert {:error, _reason} = result
    end
  end
end
