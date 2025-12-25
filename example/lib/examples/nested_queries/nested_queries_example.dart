/// Nested Queries Example
///
/// Demonstrates complex master-detail patterns with:
/// - Per-item queries (each list item fetches its own data)
/// - Modal with dependent queries
/// - Optimistic updates (no refetch needed!)
/// - Cache invalidation strategies
/// - Real-time activity tracking

// Main entry point
export 'screens/todo_list_screen.dart' show NestedQueriesScreen;

// Widgets (for documentation purposes)
export 'widgets/todo_list_item.dart' show TodoListItem;
export 'widgets/todo_details_modal.dart' show TodoDetailsModal;
export 'widgets/subtask_tile.dart' show SubtaskTile;
export 'widgets/activity_tile.dart' show ActivityTile;

// Hooks
export 'hooks/use_todo_mutations.dart' show useTodoMutations, TodoMutations;
