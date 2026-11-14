defmodule MetricFlowWeb.UserLive.AndersonBiRebrandTest do
  use MetricFlowTest.ConnCase, async: false

  import Phoenix.LiveViewTest

  @moduledoc """
  Reproduces issue 3c7037ee: the customer-facing product is still branded
  MetricFlow (page title, login heading, "New to MetricFlow?") instead of
  the approved rename to Anderson BI. Asserts against rendered text and
  user-visible attributes only, via Floki, since the raw HTML also carries
  internal identifiers (e.g. the CodeMySpec support widget's phx-hook
  module name) that the issue explicitly keeps unchanged.
  """

  test "the public login page is branded Anderson BI, not MetricFlow, in all customer-visible content",
       %{conn: conn} do
    {:ok, _view, html} = live(conn, ~p"/users/log-in")
    document = Floki.parse_document!(html)

    visible_text =
      document
      |> Floki.filter_out("script, style")
      |> Floki.text()

    visible_attrs =
      document
      |> Floki.find("[alt], [aria-label], [placeholder]")
      |> Enum.flat_map(fn el ->
        Floki.attribute(el, "alt") ++
          Floki.attribute(el, "aria-label") ++ Floki.attribute(el, "placeholder")
      end)
      |> Enum.join(" ")

    meta_content =
      document
      |> Floki.find("meta[name=description], meta[property^='og:']")
      |> Floki.attribute("content")
      |> Enum.join(" ")

    customer_visible = Enum.join([visible_text, visible_attrs, meta_content], " ")

    assert customer_visible =~ "Anderson BI"
    refute customer_visible =~ "MetricFlow"
    refute customer_visible =~ "Metric Flow"
  end
end
