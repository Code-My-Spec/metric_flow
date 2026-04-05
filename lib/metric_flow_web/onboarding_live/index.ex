defmodule MetricFlowWeb.OnboardingLive.Index do
  @moduledoc """
  Welcome page and entry point for the onboarding flow.

  Displays a welcome message and introductory text to guide new users through
  account setup. Currently a stub that will expand into a multi-step wizard
  for connecting integrations and configuring the workspace.

  Route: GET /onboarding
  """

  use MetricFlowWeb, :live_view

  # ---------------------------------------------------------------------------
  # Render
  # ---------------------------------------------------------------------------

  @impl true
  @spec render(map()) :: Phoenix.LiveView.Rendered.t()
  def render(assigns) do
    ~H"""
    <Layouts.app
      flash={@flash}
      current_scope={@current_scope}
      white_label_config={assigns[:white_label_config]}
      active_account_name={assigns[:active_account_name]}
    >
      <div class="mx-auto max-w-2xl text-center mf-content px-4 py-8">
        <.header>Welcome to MetricFlow</.header>

        <p class="mt-4 text-base-content/60">
          Let's get started setting up your account. This onboarding process will guide you through
          configuring your workspace.
        </p>
      </div>
    </Layouts.app>
    """
  end

  # ---------------------------------------------------------------------------
  # Mount
  # ---------------------------------------------------------------------------

  @impl true
  @spec mount(map(), map(), Phoenix.LiveView.Socket.t()) :: {:ok, Phoenix.LiveView.Socket.t()}
  def mount(_params, _session, socket) do
    {:ok, assign(socket, :page_title, "Onboarding")}
  end
end
