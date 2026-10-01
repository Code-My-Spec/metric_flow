defmodule MetricFlowTest.AiStub do
  @moduledoc """
  Stub for AI/LLM calls in BDD spec tests.

  Provides a fake `stream_chat/4` that invokes the given `on_chunk` callback
  with canned content word-by-word and returns the assembled text, avoiding
  real Anthropic/Claude Code CLI calls.

  ## Usage in shared givens

  Call `setup_ai_stubs/0` in a given step before any AI chat interaction:

      given_ :with_ai_stubs

  This configures the Ai context to use the fake stream function and
  registers `on_exit` cleanup.
  """

  @canned_response "Based on the data available, your revenue metrics show normal " <>
                     "seasonal variation. I'd recommend reviewing your marketing spend " <>
                     "allocation across channels for optimization opportunities."

  @doc "Returns the canned AI response text for test assertions."
  def canned_response, do: @canned_response

  @doc """
  Configures the application to use stubbed AI responses for BDD specs.
  Sets `:test_llm_options` with the fake stream function so that
  `Ai.send_chat_message/4` uses it instead of hitting the real API.
  """
  def setup_ai_stubs do
    original = Application.get_env(:metric_flow, :test_llm_options)

    Application.put_env(:metric_flow, :test_llm_options, [
      stream_chat_fn: &fake_stream_chat/4
    ])

    ExUnit.Callbacks.on_exit(fn ->
      if original do
        Application.put_env(:metric_flow, :test_llm_options, original)
      else
        Application.delete_env(:metric_flow, :test_llm_options)
      end
    end)

    :ok
  end

  @doc """
  Fake `stream_chat/4` that calls `on_chunk` with canned content word-by-word
  and returns the assembled text. No subprocess or HTTP calls are made.
  """
  def fake_stream_chat(_system_prompt, _messages, on_chunk, _opts) do
    @canned_response
    |> String.split(" ")
    |> Enum.map(&(&1 <> " "))
    |> Enum.each(&on_chunk.(&1))

    {:ok, @canned_response}
  end
end
