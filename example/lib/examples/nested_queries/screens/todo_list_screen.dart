import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:fluquery/fluquery.dart';
import '../../../api/api_client.dart';
import '../widgets/todo_list_item.dart';
import '../widgets/todo_details_modal.dart';

/// Main screen showing todos list with per-item subtask queries
class NestedQueriesScreen extends HookWidget {
  const NestedQueriesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final client = useQueryClient();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accentColor = Theme.of(context).colorScheme.primary;

    // Main todos list query
    final todosQuery = useQuery<List<Todo>, Object>(
      queryKey: ['todos'],
      queryFn: (_) => ApiClient.getTodos(),
      staleTime: const StaleTime(Duration(minutes: 2)),
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Nested Queries'),
        actions: [
          // Refresh all
          IconButton(
            icon: todosQuery.isFetching
                ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: accentColor),
                  )
                : const Icon(Icons.refresh),
            onPressed: () => todosQuery.refetch(),
            tooltip: 'Refresh todos',
          ),
          // Clear all caches
          IconButton(
            icon: const Icon(Icons.clear_all),
            onPressed: () {
              client.invalidateQueries(
                  queryKey: ['todos'], refetch: RefetchType.active);
              client.removeQueries(queryKey: ['todo-details']);
              client.removeQueries(queryKey: ['subtasks']);
              client.removeQueries(queryKey: ['todo-activities']);
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
      body: Container(
        decoration: BoxDecoration(
          gradient: isDark
              ? const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFF0F0F1A), Color(0xFF1A1A2E)],
                )
              : LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.grey.shade50, Colors.white],
                ),
        ),
        child: Column(
          children: [
            // Cache stats bar
            _CacheStatsBar(client: client),
            // Todos list
            Expanded(
              child: _buildTodosList(context, todosQuery, client),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTodosList(
    BuildContext context,
    QueryResult<List<Todo>, Object> todosQuery,
    QueryClient client,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accentColor = Theme.of(context).colorScheme.primary;

    if (todosQuery.isLoading && !todosQuery.hasData) {
      return Center(child: CircularProgressIndicator(color: accentColor));
    }

    if (todosQuery.isError) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 16),
            Text(
              'Error: ${todosQuery.error}',
              style: TextStyle(color: isDark ? Colors.white : Colors.black87),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => todosQuery.refetch(),
              style: ElevatedButton.styleFrom(backgroundColor: accentColor),
              child: const Text('Retry'),
            ),
          ],
        ),
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
            onTap: () => _showTodoDetailsModal(context, todo.id),
          );
        },
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

/// Shows cache statistics
class _CacheStatsBar extends HookWidget {
  final QueryClient client;

  const _CacheStatsBar({required this.client});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accentColor = Theme.of(context).colorScheme.primary;

    // Force rebuild periodically to update stats
    final updateTrigger = useState(0);
    useEffect(() {
      final timer = Stream.periodic(const Duration(seconds: 2)).listen((_) {
        updateTrigger.value++;
      });
      return timer.cancel;
    }, []);

    final cachedDetails = client.queryCache.queries
        .where((q) => q.queryKey.toString().contains('todo-details'))
        .length;
    final cachedSubtasks = client.queryCache.queries
        .where((q) => q.queryKey.toString().contains('subtasks'))
        .length;

    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          _StatChip(
            icon: Icons.article,
            label: 'Details',
            value: '$cachedDetails',
            color: accentColor,
          ),
          const SizedBox(width: 12),
          _StatChip(
            icon: Icons.checklist,
            label: 'Subtasks',
            value: '$cachedSubtasks',
            color: Color.lerp(accentColor, const Color(0xFF10B981), 0.5)!,
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF2A2A3E) : Colors.grey.shade100,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.info_outline,
                  size: 14,
                  color: isDark ? Colors.white54 : Colors.black38,
                ),
                const SizedBox(width: 6),
                Text(
                  'No refetch on mutations!',
                  style: TextStyle(
                    color: isDark ? Colors.white54 : Colors.black38,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _StatChip({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withAlpha(26),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withAlpha(77)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Text(
            '$label: $value cached',
            style: TextStyle(
                color: color, fontSize: 12, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }
}
