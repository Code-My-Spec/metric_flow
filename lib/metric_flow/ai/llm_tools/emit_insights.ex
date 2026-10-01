defmodule MetricFlow.Ai.LlmTools.EmitInsights do
  @moduledoc """
  Alloy forced tool: report generated marketing insights as structured data.

  Used with `until_tool: "emit_insights"` so `Alloy.run/2`'s loop does not end
  until the model calls this, which is how `LlmClient.generate_insights/3`
  gets its structured result instead of free-form text.
  """

  @behaviour Alloy.Tool

  @impl true
  def name, do: "emit_insights"

  @impl true
  def description, do: "Report the generated marketing insights."

  @impl true
  def input_schema do
    %{
      "type" => "object",
      "properties" => %{
        "insights" => %{
          "type" => "array",
          "items" => %{
            "type" => "object",
            "properties" => %{
              "summary" => %{"type" => "string"},
              "content" => %{"type" => "string"},
              "suggestion_type" => %{
                "type" => "string",
                "enum" => [
                  "budget_increase",
                  "budget_decrease",
                  "optimization",
                  "monitoring",
                  "general"
                ]
              },
              "confidence" => %{"type" => "number"}
            },
            "required" => ["summary", "content", "suggestion_type", "confidence"]
          }
        }
      },
      "required" => ["insights"]
    }
  end

  @impl true
  def execute(%{"insights" => insights} = input, _context) when is_list(insights) do
    {:ok, "Recorded #{length(insights)} insight(s).", input}
  end

  @impl true
  def result_type, do: :structured
end
