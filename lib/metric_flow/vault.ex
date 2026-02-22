defmodule MetricFlow.Vault do
  @moduledoc """
  Cloak encryption vault for encrypting sensitive fields (e.g. OAuth tokens).
  """
  use Cloak.Vault, otp_app: :metric_flow
end
