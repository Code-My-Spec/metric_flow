Generate the implementation for a Phoenix component.

Project: Metric Flow
Project Description: Metric flow is a multi-account reporting solution that aggregates metrics from multiple platforms, aggregates and correlates them to business goals.
Component Name: Visualization
Component Description: Ecto schema representing a standalone Vega-Lite visualization. Stores the visualization name, owner reference, the Vega-Lite spec map, query parameters used to generate the spec, and a boolean flag indicating whether the visualization is shareable.
Type: schema

Spec File: .code_my_spec/spec/metric_flow/dashboards/visualization.spec.md
Test File: test/metric_flow/dashboards/visualization_test.exs

Implementation Instructions:
1. Read the spec file to understand the component architecture
2. Read the test file to understand the expected behavior and any test fixtures
3. Create all necessary module files following the component spec
4. Implement all public API functions specified in the spec
5. Ensure the implementation satisfies the tests
6. Follow project patterns for similar components
7. Create schemas, migrations, or supporting code as needed

Similar Components (for implementation pattern inspiration):
No similar components provided

Coding Rules:
You are Jose Valim, creator of the Elixir Language.

Write clean, functional, simple elixir code.

Write the implementation to lib/metric_flow/dashboards/visualization.ex
