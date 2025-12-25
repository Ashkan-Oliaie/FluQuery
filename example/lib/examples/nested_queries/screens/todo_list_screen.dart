import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:fluquery/fluquery.dart';
import '../../../api/api_client.dart';
import '../../../constants/query_keys.dart';
import '../../shared/shared.dart';
import '../widgets/cache_stats_bar.dart';
import '../widgets/todo_list_item.dart';
import '../widgets/todo_details_modal.dart';

/// Main screen showing todos list with per-item subtask queries
class NestedQueriesScreen extends HookWidget {
  const NestedQueriesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final client = useQueryClient();
    final accentColor = Theme.of(context).colorScheme.primary;

    // Main todos list query
    final todosQuery = useQuery<List<Todo>, Object>(
      queryKey: QueryKeys.todos,
      queryFn: (_) => ApiClient.getTodos(),
      staleTime: const StaleTime(Duration(minutes: 2)),
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Nested Queries'),
        actions: [
          IconButton(
            icon: todosQuery.isFetching
                ? SmallSpinner(color: accentColor)
                : const Icon(Icons.refresh),
            onPressed: () => todosQuery.refetch(),
            tooltip: 'Refresh todos',
          ),
          IconButton(
            icon: const Icon(Icons.clear_all),
            onPressed: () {
              client.invalidateQueries(
                queryKey: QueryKeys.todos,
                refetch: RefetchType.active,
              );
              client.removeQueries(queryKey: QueryKeys.todoDetails);
              client.removeQueries(queryKey: QueryKeys.subtasks);
              client.removeQueries(queryKey: QueryKeys.todoActivities);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text('All caches cleared'),
                  backgroundColor: accentColor,
                ),
              );
            },
            tooltip: 'Clear all caches',
          ),
        ],
      ),
      body: GradientBackground(
        child: Column(
          children: [
            CacheStatsBar(client: client),
            Expanded(
              child: _TodosList(
                todosQuery: todosQuery,
                onTodoTap: (todoId) => _showTodoDetailsModal(context, todoId),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showTodoDetailsModal(BuildContext context, int todoId) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.9,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (context, scrollController) => TodoDetailsModal(
          todoId: todoId,
          scrollController: scrollController,
        ),
      ),
    );
  }
}

class _TodosList extends StatelessWidget {
  final QueryResult<List<Todo>, Object> todosQuery;
  final void Function(int todoId) onTodoTap;

  const _TodosList({
    required this.todosQuery,
    required this.onTodoTap,
  });

  @override
  Widget build(BuildContext context) {
    final accentColor = Theme.of(context).colorScheme.primary;

    if (todosQuery.isLoading && !todosQuery.hasData) {
      return const LoadingIndicator();
    }

    if (todosQuery.isError) {
      return ErrorView(
        error: todosQuery.error,
        onRetry: () => todosQuery.refetch(),
      );
    }

    final todos = todosQuery.data ?? [];

    return RefreshIndicator(
      color: accentColor,
      onRefresh: () => todosQuery.refetch(),
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: todos.length,
        itemBuilder: (context, index) {
          final todo = todos[index];
          return TodoListItem(
            todo: todo,
            onTap: () => onTodoTap(todo.id),
          );
        },
      ),
    );
  }
}
