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
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.refresh),
            onPressed: () => todosQuery.refetch(),
            tooltip: 'Refresh todos',
          ),
          // Clear all caches
          IconButton(
            icon: const Icon(Icons.clear_all),
            onPressed: () {
              client.invalidateQueries(queryKey: ['todos'], refetchType: true);
              client.removeQueries(queryKey: ['todo-details']);
              client.removeQueries(queryKey: ['subtasks']);
              client.removeQueries(queryKey: ['todo-activities']);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('All caches cleared')),
              );
            },
            tooltip: 'Clear all caches',
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF0F0F1A), Color(0xFF1A1A2E)],
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
    if (todosQuery.isLoading && !todosQuery.hasData) {
      return const Center(child: CircularProgressIndicator());
    }

    if (todosQuery.isError) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 16),
            Text('Error: ${todosQuery.error}', style: const TextStyle(color: Colors.white)),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => todosQuery.refetch(),
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    final todos = todosQuery.data ?? [];

    return RefreshIndicator(
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
            color: const Color(0xFF6366F1),
          ),
          const SizedBox(width: 12),
          _StatChip(
            icon: Icons.checklist,
            label: 'Subtasks',
            value: '$cachedSubtasks',
            color: const Color(0xFF10B981),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFF2A2A3E),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.info_outline,
                  size: 14,
                  color: Colors.white.withAlpha(128),
                ),
                const SizedBox(width: 6),
                Text(
                  'No refetch on mutations!',
                  style: TextStyle(
                    color: Colors.white.withAlpha(128),
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
            style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }
}


