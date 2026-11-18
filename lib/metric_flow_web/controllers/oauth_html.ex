defmodule MetricFlowWeb.OAuthHTML do
  @moduledoc "Consent and error pages for the OAuth authorization server."
  use MetricFlowWeb, :html

  embed_templates "oauth_html/*"
end
