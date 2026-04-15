defmodule MetricFlowWeb.OnboardingLive do
  use MetricFlowWeb, :live_view

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.content flash={@flash} current_scope={@current_scope} active_account_name={assigns[:active_account_name]}
      active_account_type={assigns[:active_account_type]}>
      <div class="mx-auto max-w-2xl text-center">
        <.header>Welcome to MetricFlow</.header>

        <p class="mt-4">
          Let's get started setting up your account. This onboarding process will guide you through
          configuring your workspace.
        </p>
      </div>
    </Layouts.content>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket}
  end
end
