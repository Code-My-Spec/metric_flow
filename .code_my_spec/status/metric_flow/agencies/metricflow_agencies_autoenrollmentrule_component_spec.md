Generate a Phoenix component spec for the following.
Project: Metric FLow
Project Description: Metric flow is a multi-account reporting solution that aggregates metrics from multiple platforms, aggregates and correlates them to business goals.
Component Name: AutoEnrollmentRule
Component Description: Domain-based auto-enrollment config
Type: module

The implementation doesn't exist yet.
The tests don't exist yet.

Design Rules:


Document Specifications:
# Module

Spec documents provide comprehensive documentation for Elixir modules following a
structured format. Each spec includes module metadata, public API documentation,
delegation information, dependencies, and detailed function specifications.

Specs are parsed using convention-based section parsers:
- "functions" section → Documents.Parsers.FunctionParser (returns structured Function schemas)
- "fields" section → Documents.Parsers.FieldParser (returns structured Field schemas)
- Other sections → Plain text extraction

Specs should focus on WHAT the module does, not HOW it does it. Keep them concise
and human-readable, as they're consumed by both humans and AI agents.


## Required Sections

### Delegates

Format:
- Use H2 heading
- Simple bullet list of delegate function definitions

Content:
- Each item shows function/arity delegation in format: function_name/arity: Target.Module.function_name/arity
- Only include functions that are delegated to other modules

Examples:
- ## Delegates
  - list_components/1: Components.ComponentRepository.list_components/1
  - get_component/2: Components.ComponentRepository.get_component/2


### Functions

Format:
- Use H2 heading
- Use H3 headers for each function in format: function_name/arity

Content:
- Document only PUBLIC functions (not private functions)
- Each function should include:
  * Brief description of what the function does
  * Elixir @spec in code block
  * **Process**: Step-by-step description of the function's logic
  * **Test Assertions**: List of test cases for this function

Examples:
- ## Functions
  ### build/1
  Apply dependency tree processing to all components.
  ```elixir
  @spec build([Component.t()]) :: [Component.t()]
  ```
  **Process**:
  1. Topologically sort components to process dependencies first
  2. Reduce over sorted components, building a map of processed components
  **Test Assertions**:
  - returns empty list for empty input
  - processes components in dependency order


### Dependencies

Format:
- Use H2 heading
- Simple bullet list of module names

Content:
- Each item must be a valid Elixir module name (PascalCase)
- No descriptions - just the module names
- Only include modules this module depends on

Examples:
- ## Dependencies
  - CodeMySpec.Components
  - CodeMySpec.Utils


## Optional Sections

### Fields

Format:
- Use H2 heading
- Table format with columns: Field, Type, Required, Description, Constraints

Content:
- Only applicable for schemas and structs
- List all schema fields with their Ecto types
- Mark required fields clearly (Yes/No or Yes (auto) for auto-generated)
- Include constraints (length, format, references)

Examples:
- ## Fields
  | Field       | Type         | Required   | Description           | Constraints         |
  | ----------- | ------------ | ---------- | --------------------- | ------------------- |
  | id          | integer      | Yes (auto) | Primary key           | Auto-generated      |
  | name        | string       | Yes        | Name field            | Min: 1, Max: 255    |
  | foreign_id  | integer      | Yes        | Foreign key           | References table.id |



Write the document to docs/spec/metric_flow/agencies/auto_enrollment_rule.spec.md.
