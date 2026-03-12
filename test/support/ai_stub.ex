defmodule MetricFlowTest.AiStub do
  @moduledoc """
  Stub for AI/LLM calls in BDD spec tests.

  Provides a fake `stream_chat/3` that returns a `ReqLLM.StreamResponse`
  with canned content, avoiding real Anthropic API calls. The stream emits
  content chunks that the Ai context's `collect_stream/2` can consume.

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
      stream_chat_fn: &fake_stream_chat/3
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
  Fake `stream_chat/3` that returns a `ReqLLM.StreamResponse` with canned
  content chunks. No HTTP calls are made.
  """
  def fake_stream_chat(_system_prompt, _messages, _opts) do
    # Build content chunks matching what ReqLLM streams
    chunks =
      @canned_response
      |> String.split(" ")
      |> Enum.map(fn word -> %{type: :content, text: word <> " "} end)

    # Fake metadata handle — returns immediately with stubbed usage
    metadata_task =
      Task.async(fn ->
        %{input_tokens: 50, output_tokens: String.length(@canned_response)}
      end)

    stream_response = %ReqLLM.StreamResponse{
      stream: Stream.concat(chunks, [%{type: :done}]),
      metadata_handle: metadata_task,
      cancel: fn -> :ok end,
      model: %{provider: :anthropic, name: "stub-model", id: "stub"},
      context: %ReqLLM.Context{messages: []}
    }

    {:ok, stream_response}
  end
end
