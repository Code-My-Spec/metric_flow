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
      <div class="mx-auto max-w-3xl overflow-x-hidden px-4 py-8">
        <div class="mb-8">
          <h1 class="text-2xl font-bold text-base-content">Welcome to Anderson BI</h1>
          <p class="mt-1 text-base-content/70">
            Let's get started setting up your account. Connect a platform to bring your metrics into Anderson BI.
          </p>
        </div>

        <ol
          id="wizard-stepper"
          class="mb-8 flex flex-wrap items-center gap-2 text-sm"
        >
          <li
            id="wizard-step-welcome"
            data-current="false"
            data-done="true"
            class="flex min-w-0 items-center gap-2"
          >
            <span class="flex items-center gap-2 rounded-box px-3 py-1.5">
              <span class="flex size-6 shrink-0 items-center justify-center rounded-full bg-success text-success-content text-xs">
                <.icon name="hero-check-mini" class="size-4" />
              </span>
              <span class="hidden sm:inline">Sign in</span>
            </span>
            <span class="hidden h-px w-6 bg-neutral sm:inline-block sm:flex-1"></span>
          </li>

          <li
            id="wizard-step-connect"
            data-current="true"
            data-done="false"
            class="flex min-w-0 items-center gap-2"
          >
            <span class="flex items-center gap-2 rounded-box bg-primary px-3 py-1.5 font-semibold text-primary-content">
              <span class="flex size-6 shrink-0 items-center justify-center rounded-full bg-primary-content/20 text-xs">
                2
              </span>
              <span>Connect data</span>
            </span>
            <span class="hidden h-px w-6 bg-neutral sm:inline-block sm:flex-1"></span>
          </li>

          <li
            id="wizard-step-dashboard"
            data-current="false"
            data-done="false"
            class="flex min-w-0 items-center gap-2"
          >
            <span class="flex items-center gap-2 rounded-box px-3 py-1.5">
              <span class="flex size-6 shrink-0 items-center justify-center rounded-full bg-base-300 text-xs">
                3
              </span>
              <span class="hidden sm:inline">Open dashboard</span>
            </span>
          </li>
        </ol>

        <section
          id="onboarding-next-steps"
          class="rounded-box border border-neutral bg-base-200 p-4 sm:p-6"
        >
          <h2 class="text-xl font-semibold text-base-content">Connect your data</h2>
          <p class="mt-1 text-sm text-base-content/70">
            Connect a marketing or financial platform, then choose the accounts or properties to sync.
            Once your data is synced, open the dashboard to explore your metrics.
          </p>

          <.link
            id="onboarding-connect-platforms"
            navigate={~p"/app/onboarding/connect"}
            class="btn-brand-gradient mt-6 inline-flex w-full items-center justify-center rounded-box px-4 py-2 text-center sm:w-auto"
          >
            Connect your data
          </.link>

          <p class="mt-6 border-t border-neutral pt-4 text-sm text-base-content/70">
            Already synced?
            <.link
              id="onboarding-open-dashboard"
              navigate={~p"/app/dashboard"}
              class="font-semibold text-primary hover:underline"
            >
              Open the dashboard
            </.link>
            .
          </p>
        </section>
      </div>
    </Layouts.app>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket}
  end
end
