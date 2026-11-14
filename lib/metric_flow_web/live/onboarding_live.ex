defmodule MetricFlowWeb.OnboardingLive do
  use MetricFlowWeb, :live_view

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app
      flash={@flash}
      current_scope={@current_scope}
      active_account_name={assigns[:active_account_name]}
    >
      <div class="mx-auto max-w-2xl text-center">
        <.header>Welcome to Anderson BI</.header>

        <p class="mt-4">
          Let's get started setting up your account. Connect a platform to bring your metrics into Anderson BI.
        </p>
        <div
          id="onboarding-next-steps"
          class="mt-6 rounded-xl border border-base-content/15 bg-base-200/40 p-6 text-left"
        >
          <h2 class="text-lg font-semibold">Start with your data</h2>
          <p class="mt-2 text-sm text-base-content/70">
            Connect a marketing or financial platform, then choose the accounts or properties to sync.
            Once your data is synced, open the dashboard to explore your metrics.
          </p>
          <p class="mt-3 text-sm text-base-content/70">
            Managing clients as an agency? Open the app to set up your client accounts and manage their reporting.
          </p>
          <div class="mt-5 flex flex-col gap-3 sm:flex-row">
            <.link
              id="onboarding-connect-platforms"
              navigate={~p"/app/integrations"}
              class="inline-flex justify-center rounded-lg bg-primary px-4 py-3 font-semibold text-primary-content transition-opacity hover:opacity-90 focus-visible:outline-2"
            >
              Connect your platforms
            </.link>
            <.link
              id="onboarding-open-dashboard"
              navigate={~p"/app/dashboard"}
              class="inline-flex justify-center rounded-lg border border-base-content/20 px-4 py-3 font-medium transition-colors hover:bg-base-200 focus-visible:outline-2"
            >
              Open the app
            </.link>
          </div>
        </div>
      </div>
    </Layouts.app>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket}
  end
end
