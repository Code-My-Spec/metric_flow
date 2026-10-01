defmodule MetricFlow.Integrations.IntegrationNotifier do
  @moduledoc """
  Delivers integration-lifecycle emails (e.g. expired credentials) using Swoosh.
  """

  import Swoosh.Email

  alias MetricFlow.Mailer

  @doc """
  Delivers a notification to the user when an integration's credentials have
  expired and it needs to be reconnected.

  Accepts the owner's email and the provider's display name. Returns
  `{:ok, email}` on successful delivery.
  """
  @spec deliver_reconnection_required(String.t(), String.t()) ::
          {:ok, Swoosh.Email.t()} | {:error, term()}
  def deliver_reconnection_required(owner_email, provider_name) do
    deliver_email(owner_email, "Reconnect your #{provider_name} integration", """

    ==============================

    Hi #{owner_email},

    Your #{provider_name} connection's credentials have expired, so syncing has
    stopped. Please reconnect it from the Integrations page to resume syncing.

    ==============================
    """)
  end

  defp deliver_email(recipient, subject, body) do
    email =
      new()
      |> to(recipient)
      |> from({"MetricFlow", "noreply@metric-flow.app"})
      |> subject(subject)
      |> text_body(body)

    with {:ok, _metadata} <- Mailer.deliver(email) do
      {:ok, email}
    end
  end
end
