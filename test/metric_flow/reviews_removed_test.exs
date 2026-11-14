defmodule MetricFlow.ReviewsRemovedTest do
  use ExUnit.Case, async: true

  # MetricFlow.Reviews.Review/ReviewRepository/Reviews context (issue
  # 2fcafcfd) have zero live callers: every real review-metrics read goes
  # through Metrics.ReviewMetrics over Metric rows with metric_type
  # "reviews", already exercised by spex story 39
  # (MetricFlowSpex.Fixtures.create_review_for/2 inserts Metric rows, not
  # Reviews.Review rows). This file lives outside lib/metric_flow/reviews/
  # so it survives the coder deleting those modules and their own tests.

  test "MetricFlow.Reviews is no longer defined" do
    refute Code.ensure_loaded?(MetricFlow.Reviews)
  end

  test "MetricFlow.Reviews.Review is no longer defined" do
    refute Code.ensure_loaded?(MetricFlow.Reviews.Review)
  end

  test "MetricFlow.Reviews.ReviewRepository is no longer defined" do
    refute Code.ensure_loaded?(MetricFlow.Reviews.ReviewRepository)
  end
end
