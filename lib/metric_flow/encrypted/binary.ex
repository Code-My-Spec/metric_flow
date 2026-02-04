defmodule MetricFlow.Encrypted.Binary do
  use Cloak.Ecto.Binary, vault: MetricFlow.Infrastructure.Vault
end
