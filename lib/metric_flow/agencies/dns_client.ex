defmodule MetricFlow.Agencies.DnsClient do
  @moduledoc """
  Wraps Erlang's `:inet_res` for DNS lookups.

  Swappable via `Application.put_env(:metric_flow, :dns_client, MyStub)`
  for testing.
  """

  @callback lookup_cname(String.t()) :: [String.t()]

  @doc """
  Looks up CNAME records for the given hostname.

  Returns a list of CNAME target strings (without trailing dots).
  """
  @spec lookup_cname(String.t()) :: [String.t()]
  def lookup_cname(hostname) do
    hostname
    |> String.to_charlist()
    |> :inet_res.lookup(:in, :cname)
    |> Enum.map(fn cname -> cname |> to_string() |> String.trim_trailing(".") end)
  end
end
