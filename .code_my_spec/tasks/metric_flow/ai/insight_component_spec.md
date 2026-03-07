<!-- cms:task type="ComponentSpec" component="MetricFlow.Ai.Insight" -->

Generate a Phoenix component spec for the following.
Project: Metric FLow
Project Description: Metric flow is a multi-account reporting solution that aggregates metrics from multiple platforms, aggregates and correlates them to business goals.
Component Name: Insight
Component Description: Generated insight: account_id, correlation_id, content, type
Type: schema

Existing Implementation: lib/metric_flow/ai/insight.ex.
Existing tests: test/metric_flow/ai/insight_test.exs

Design Rules:
# Collaboration Guidelines
- **Challenge and question**: Don't immediately agree or proceed with requests that seem suboptimal, unclear, or potentially problematic
- **Push back constructively**: If a proposed approach has issues, suggest better alternatives with clear reasoning
- **Think critically**: Consider edge cases, performance implications, maintainability, and best practices before implementing
- **Seek clarification**: Ask follow-up questions when requirements are ambiguous or could be interpreted multiple ways
- **Propose improvements**: Suggest better patterns, more robust solutions, or cleaner implementations when appropriate
- **Be a thoughtful collaborator**: Act as a good teammate who helps improve the overall quality and direction of the project

# Ecto Schema Design Rules

- Write your design in plain english, some code samples are fine
- Consider loose coupling with ID fields only when appropriate
- Document relationship patterns
- Comment field purposes and constraints
- Document state transitions for enums
- Note any special business rules

- Structure applications as hierarchical supervision trees
- Put critical, stable processes at the top and volatile, expendable processes at the bottom
- Use OTP behaviors (GenServer, Supervisor, GenStateMachine) as design patterns for processes.
- Don't try to handle every edge case
- Fail predictably and quickly and recover automatically using supervision
- Design the application as independent processes, communicating via message passing
- Each process should have a single, clear responsibility with well-defined boundaries
- Model complex business processes as explicit state machines using GenStateMachine or similar patterns
- Design for distribution from day one, using distributed Erlang capabilities for seamless process communication across nodes
- Architect applications so components can be upgraded, replaced, or scaled without system shutdown using hot code swapping
- Design a functional core containing pure business logic and an imperative shell handling side effects
- The shell can call the core, but not vice versa

Use coordination contexts for cross-context operations instead of adopting layered architectures. Create explicit coordination modules when operations span multiple bounded contexts while maintaining context autonomy.

Design Phoenix Contexts as bounded context boundaries that decouple and isolate parts of your application, following Domain-Driven Design principles. Each context should encapsulate data access, validation, and business logic for a specific domain with clear boundaries.

You run in an environment where ast-grep is available; whenever a search requires syntax-aware or structural matching, default to ast-grep --lang elixir -p '<pattern>' (or set --lang appropriately) and avoid falling back to text-only tools like rg or grep unless I explicitly request a plain-text search.

Document Specifications:
# Schema

Schema components represent Ecto schema entities that define data structures,
relationships, and validation rules for persistence in the database. Each schema
documents its fields, associations, validations, and database constraints.


## Required Sections

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


## Optional Sections

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



Write the document to .code_my_spec/spec/metric_flow/ai/insight.spec.md.
