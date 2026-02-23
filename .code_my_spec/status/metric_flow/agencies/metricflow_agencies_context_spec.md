Your task is to generate a specification for a Phoenix bounded context.

# Project

Project: Metric FLow
Project Description: Metric flow is a multi-account reporting solution that aggregates metrics from multiple platforms, aggregates and correlates them to business goals.

# Bounded context

Context Name: Agencies
Context Description: Agency-specific features: team management, white-labeling, client account origination.
Type: context

# User Stories this context satisfies
No user stories provided

# Similar Components
No similar components provided

# How to write the document
# Context Spec

Spec documents provide comprehensive documentation for Elixir modules following a
structured format. Each spec includes module metadata, public API documentation,
delegation information, dependencies, detailed function specifications, and
titles and brief descriptions of components contained by the context.

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


### Components

Format:
- Use H2 heading
- Use H3 headers for each component module
- Include description text

Content:
- Module names must be valid Elixir modules (PascalCase)
- Include brief description
- Focus on architectural relationships, not implementation details
- Show clear separation of concerns
- Indicate behavior contracts where applicable
- Use consistent naming conventions
- Component types are user-defined strings matching your architecture

Examples:
- ## Components
  ### ModuleName

  Brief description of the component's responsibility.


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



# Design Rules


Please write the specification to: docs/spec/metric_flow/agencies.spec.md
