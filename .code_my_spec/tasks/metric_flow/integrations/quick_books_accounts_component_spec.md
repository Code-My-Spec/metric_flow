Generate a Phoenix component spec for the following.
Project: Metric Flow
Project Description: Metric flow is a multi-account reporting solution that aggregates metrics from multiple platforms, aggregates and correlates them to business goals.
Component Name: QuickBooksAccounts
Component Description: No description provided
Type: module

The implementation doesn't exist yet.
The tests don't exist yet.

Design Rules:
# Collaboration Guidelines
- **Challenge and question**: Don't immediately agree or proceed with requests that seem suboptimal, unclear, or potentially problematic
- **Push back constructively**: If a proposed approach has issues, suggest better alternatives with clear reasoning
- **Think critically**: Consider edge cases, performance implications, maintainability, and best practices before implementing
- **Seek clarification**: Ask follow-up questions when requirements are ambiguous or could be interpreted multiple ways
- **Propose improvements**: Suggest better patterns, more robust solutions, or cleaner implementations when appropriate
- **Be a thoughtful collaborator**: Act as a good teammate who helps improve the overall quality and direction of the project

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



Write the document to .code_my_spec/spec/metric_flow/integrations/quick_books_accounts.spec.md.
