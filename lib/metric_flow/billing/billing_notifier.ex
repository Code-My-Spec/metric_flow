defmodule MetricFlow.Billing.BillingNotifier do
  @moduledoc """
  Sends transactional emails for billing events.
  """

  import Swoosh.Email

  alias MetricFlow.Mailer

  defp deliver(recipient, subject, body) do
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

  @doc """
  Deliver a notice that a subscription payment failed, prompting the user
  to update their payment method.
  """
  def deliver_payment_failed(email) do
    deliver(email, "Payment failed on your MetricFlow subscription", """

    ==============================

    Hi #{email},

    We were unable to process your most recent subscription payment.
    Your account has been marked past due. Please update your payment
    method to avoid interruption of service.

    ==============================
    """)
  end
end
