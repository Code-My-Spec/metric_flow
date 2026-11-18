defmodule MetricFlowWeb.SetupComponents do
  @moduledoc """
  Data-source status pieces shared by the setup wizard, the integrations
  page and the dashboard's "Finish setup" checklist, so a product reads the
  same everywhere. Statuses are `MetricFlow.Onboarding` product statuses.
  """

  use Phoenix.Component

  import MetricFlowWeb.CoreComponents, only: [icon: 1]

  attr :status, :atom, required: true
  attr :class, :string, default: nil
  attr :rest, :global

  @doc "Badge for a product status (`:ready`, `:needs_selection`, …)."
  def status_badge(assigns) do
    ~H"""
    <span
      class={["badge badge-sm shrink-0 whitespace-nowrap", badge_class(@status), @class]}
      data-product-status={@status}
      {@rest}
    >
      {status_label(@status)}
    </span>
    """
  end

  attr :status, :list, required: true, doc: "`MetricFlow.Onboarding.status/1`"

  @doc """
  Compact checklist of the three connections with a link into the wizard.
  Renders only while a connected source still needs a selection or a
  reconnect — a platform the account never connected doesn't nag.
  """
  def finish_setup_checklist(assigns) do
    assigns =
      assign(
        assigns,
        :unfinished?,
        Enum.any?(assigns.status, &(&1.state in [:needs_selection, :reconnect]))
      )

    ~H"""
    <div
      :if={@unfinished?}
      id="finish-setup"
      class="mb-6 flex flex-col gap-4 rounded-box border border-base-300 bg-base-100 p-4 sm:flex-row sm:items-center sm:justify-between"
    >
      <div class="min-w-0">
        <p class="font-semibold">Finish setting up your data</p>
        <ul class="mt-2 flex flex-wrap gap-x-4 gap-y-1 text-sm">
          <li
            :for={conn <- @status}
            id={"finish-setup-#{conn.key}"}
            data-state={conn.state}
            class="flex items-center gap-1.5"
          >
            <.icon
              name={
                if conn.state == :done, do: "hero-check-circle-mini", else: "hero-minus-circle-mini"
              }
              class={"size-4 " <> icon_color(conn.state)}
            />
            <span>{conn.name}</span>
            <span class="text-base-content/60">— {state_label(conn.state)}</span>
          </li>
        </ul>
      </div>
      <.link
        id="finish-setup-link"
        navigate="/app/onboarding/connect"
        class="btn btn-primary btn-sm shrink-0"
      >
        Finish setup
      </.link>
    </div>
    """
  end

  @doc "Label for a product status."
  def status_label(:ready), do: "Active"
  def status_label(:needs_selection), do: "Choose what to sync"
  def status_label(:not_granted), do: "Not granted"
  def status_label(:reconnect), do: "Reconnect needed"
  def status_label(_), do: "Not connected"

  @doc "Label for a connection state (`MetricFlow.Onboarding` `state`)."
  def state_label(:done), do: "set up"
  def state_label(:needs_selection), do: "choose what to sync"
  def state_label(:reconnect), do: "reconnect needed"
  def state_label(_), do: "not connected"

  defp icon_color(:done), do: "text-success"
  defp icon_color(:reconnect), do: "text-warning"
  defp icon_color(_), do: "text-base-content/40"

  defp badge_class(:ready), do: "badge-success"
  defp badge_class(:needs_selection), do: "badge-info"
  defp badge_class(:reconnect), do: "badge-error"
  defp badge_class(_), do: "badge-ghost"
end
