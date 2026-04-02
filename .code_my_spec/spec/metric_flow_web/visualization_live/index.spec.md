# MetricFlowWeb.VisualizationLive.Index

Lists saved visualizations for the authenticated user. Shows all standalone visualizations with name, shareable status, edit/delete actions, and inline delete confirmation. Empty state prompts creation.

## Type

module

## Delegates

None

## Dependencies

- MetricFlow.Dashboards

## Functions

### mount/3

Loads all visualizations for the current user.

```elixir
@spec mount(map(), map(), Phoenix.LiveView.Socket.t()) :: {:ok, Phoenix.LiveView.Socket.t()}
```

**Process**:
1. Call `Dashboards.list_visualizations(scope)` to load user's visualizations
2. Assign visualizations list and `confirming_delete: nil` to socket

**Test Assertions**:
- renders visualization list for authenticated user
- shows empty state when user has no visualizations
- redirects unauthenticated user to login

### handle_event/3 ("delete")

Shows inline delete confirmation for a visualization.

```elixir
@spec handle_event(String.t(), map(), Phoenix.LiveView.Socket.t()) :: {:noreply, Phoenix.LiveView.Socket.t()}
```

**Process**:
1. Set `confirming_delete` assign to the visualization ID

**Test Assertions**:
- shows delete confirmation for the targeted visualization

### handle_event/3 ("cancel_delete")

Cancels the inline delete confirmation.

```elixir
@spec handle_event(String.t(), map(), Phoenix.LiveView.Socket.t()) :: {:noreply, Phoenix.LiveView.Socket.t()}
```

**Process**:
1. Set `confirming_delete` assign to nil

**Test Assertions**:
- hides delete confirmation

### handle_event/3 ("confirm_delete")

Permanently deletes the visualization and removes it from the list.

```elixir
@spec handle_event(String.t(), map(), Phoenix.LiveView.Socket.t()) :: {:noreply, Phoenix.LiveView.Socket.t()}
```

**Process**:
1. Call `Dashboards.delete_visualization(scope, id)`
2. On success, remove from visualizations list, clear confirming_delete, flash success
3. On not_found, clear confirming_delete, flash error

**Test Assertions**:
- removes visualization from list and flashes success
- flashes error when visualization not found

### render/1

Renders the visualization index page with grid of cards or empty state.

```elixir
@spec render(map()) :: Phoenix.LiveView.Rendered.t()
```

**Process**:
1. Render page header with "Visualizations" title and "New Visualization" button
2. If no visualizations, render empty state with create prompt
3. If visualizations exist, render responsive grid of cards
4. Each card shows name, shareable badge, edit link, delete button
5. If confirming_delete matches a card, show inline confirmation

**Test Assertions**:
- renders visualization cards with data-role attributes
- renders new visualization button
- renders edit and delete buttons per card
- shows inline confirmation when confirming_delete is set
