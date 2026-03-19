Generate the implementation for a Phoenix component.

Project: Metric Flow
Project Description: Metric flow is a multi-account reporting solution that aggregates metrics from multiple platforms, aggregates and correlates them to business goals.
Component Name: QuickBooksOAuth2
Component Description: Custom Assent OAuth2 strategy for QuickBooks Online that skips the userinfo fetch. QuickBooks uses OAuth 2.0 for token exchange but does not reliably support the OpenID Connect userinfo endpoint for the `com.intuit.quickbooks.accounting` scope. The `realmId` (company ID) is returned as a query parameter on the callback URL rather than from a userinfo endpoint. This strategy overrides the base OAuth2 behavior to complete token exchange without a userinfo HTTP call, returning an empty map as the user payload.
Type: module

Spec File: .code_my_spec/spec/metric_flow/integrations/strategies/quick_books_o_auth2.spec.md
Test File: test/metric_flow/integrations/strategies/quick_books_o_auth2_test.exs

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

Identify what should be separate modules. 
Each modules must have a single, clear responsibility. 
Never put multiple concerns in one modules.

Replace cond with pattern matching.
Replace if/else statements with pattern matching. 
Match on function heads, case statements, and with clauses. 
If you can't pattern match it, redesign the data structure.
Use with blocks over multiple nested conditionals.

Never modify existing data. 
Always return new data structures. 
Use the pipe operator `|>` to chain transformations. 
Reject any solution that requires mutable state.

Validate inputs at process boundaries using guards, pattern matching, or explicit validation. 
Crash the process rather than propagating invalid data through the system.

Separate pure functions from side effects. 
Use dedicated processes for I/O operations. 
Never hide side effects inside seemingly pure functions.

Define custom types and structs that make invalid combinations impossible. 
Use guards and specs to enforce constraints at compile time and runtime.

Processes must communicate exclusively through message passing. 
Never share memory or state between processes.
Design clear message protocols for each interaction.

Handle the Happy Path, Let Everything Else Crash. 
Focus code on the expected successful execution path. 
Don't try to handle every possible error - let the supervisor handle process failures and restarts.

Write tests that verify message passing between processes and supervision behavior. Test that processes crash appropriately and recover correctly.

# Collaboration Guidelines
- **Challenge and question**: Don't immediately agree or proceed with requests that seem suboptimal, unclear, or potentially problematic
- **Push back constructively**: If a proposed approach has issues, suggest better alternatives with clear reasoning
- **Think critically**: Consider edge cases, performance implications, maintainability, and best practices before implementing
- **Seek clarification**: Ask follow-up questions when requirements are ambiguous or could be interpreted multiple ways
- **Propose improvements**: Suggest better patterns, more robust solutions, or cleaner implementations when appropriate
- **Be a thoughtful collaborator**: Act as a good teammate who helps improve the overall quality and direction of the project

You run in an environment where ast-grep is available; whenever a search requires syntax-aware or structural matching, default to ast-grep --lang elixir -p '<pattern>' (or set --lang appropriately) and avoid falling back to text-only tools like rg or grep unless I explicitly request a plain-text search.

Write the implementation to lib/metric_flow/integrations/strategies/quick_books_o_auth2.ex
