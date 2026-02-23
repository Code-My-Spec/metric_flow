<!-- code_my_spec:start -->
## CodeMySpec Project

Read `.code_my_spec/AGENTS.md` for the full project development guide.

### Key Conventions

- All public context functions take `%Scope{}` as the first parameter
- Contexts are the public API boundary — never call child modules directly
- Use `use Boundary` in every module to enforce dependency rules
- Check `.code_my_spec/architecture/overview.md` for the component graph before adding dependencies

### Before Writing Code

1. Check `.code_my_spec/status/metric_flow.md` for implementation status
2. Read the spec in `.code_my_spec/spec/` for the module you're working on
3. Read the rules in `.code_my_spec/rules/` for the component type (context, repository, schema, etc.)
4. Check `.code_my_spec/issues/` for known problems in the area
<!-- code_my_spec:end -->
