defmodule OnboardingLive.Index do
  @moduledoc """
  Welcome page and entry point for the onboarding flow.

  Displays a welcome message and introductory text to guide new users through
  account setup. Delegates to MetricFlowWeb.OnboardingLive.Index for the actual
  LiveView implementation.
  """

  defdelegate mount(params, session, socket), to: MetricFlowWeb.OnboardingLive.Index
  defdelegate render(assigns), to: MetricFlowWeb.OnboardingLive.Index
end
