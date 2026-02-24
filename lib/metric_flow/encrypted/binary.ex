defmodule MetricFlow.Encrypted.Binary do
  @moduledoc """
  Cloak.Ecto type for encrypting binary (string) values at rest using the
  MetricFlow.Vault encryption vault.

  Use this type for sensitive fields such as OAuth access tokens and refresh
  tokens. Values are transparently encrypted on write and decrypted on read
  via the configured AES-GCM cipher.
  """

  use Cloak.Ecto.Binary, vault: MetricFlow.Vault
end
