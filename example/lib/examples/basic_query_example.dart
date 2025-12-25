import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:fluquery/fluquery.dart';
import '../api/api_client.dart';

class BasicQueryExample extends HookWidget {
  const BasicQueryExample({super.key});

  @override
  Widget build(BuildContext context) {
    final client = useQueryClient();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accentColor = Theme.of(context).colorScheme.primary;

    // Use FluQuery's useQuery hook to fetch todos
    final todosQuery = useQuery<List<Todo>, Object>(
      queryKey: ['todos'],
      queryFn: (_) => ApiClient.getTodos(),
      staleTime: const StaleTime(Duration(seconds: 20)),
      retry: 3,
      refetchInterval: const Duration(seconds: 15),
      refetchOnWindowFocus: true,
      refetchOnMount: true,
      refetchOnReconnect: true,
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Basic Query'),
        actions: [
          IconButton(
            icon: const Icon(Icons.sync_problem),
            tooltip: 'Invalidate Cache',
            onPressed: () {
              client.invalidateQueries(
                  queryKey: ['todos'], refetch: RefetchType.active);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text('Cache invalidated - refetching...'),
                  duration: const Duration(seconds: 1),
                  backgroundColor: accentColor,
                ),
              );
            },
          ),
          IconButton(
            icon: todosQuery.isFetching
                ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: accentColor),
                  )
                : const Icon(Icons.refresh),
            tooltip: 'Refetch',
            onPressed:
                todosQuery.isFetching ? null : () => todosQuery.refetch(),
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
        child: _buildContent(context, todosQuery, client),
      ),
    );
  }

  Widget _buildContent(BuildContext context,
      QueryResult<List<Todo>, Object> query, QueryClient client) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accentColor = Theme.of(context).colorScheme.primary;

    if (query.isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: accentColor),
            const SizedBox(height: 16),
            Text(
              'Loading todos...',
              style: TextStyle(color: isDark ? Colors.white70 : Colors.black54),
            ),
          ],
        ),
      );
    }

    if (query.isError) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                'Error: ${query.error}',
                style: const TextStyle(color: Colors.red),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => query.refetch(),
              style: ElevatedButton.styleFrom(backgroundColor: accentColor),
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    final todos = query.data ?? [];
    return Column(
      children: [
        // Status bar
        Container(
          padding: const EdgeInsets.all(16),
          margin: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark
                ? Color.lerp(const Color(0xFF1A1A2E), accentColor, 0.05)
                : Color.lerp(Colors.white, accentColor, 0.03),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: accentColor.withAlpha(isDark ? 40 : 25)),
            boxShadow: [
              BoxShadow(
                color: accentColor.withAlpha(isDark ? 15 : 20),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _StatusChip(
                    label: 'Total',
                    value: '${todos.length}',
                    color: accentColor,
                  ),
                  _StatusChip(
                    label: 'Done',
                    value: '${todos.where((t) => t.completed).length}',
                    color: Color.lerp(accentColor, Colors.green, 0.5)!,
                  ),
                  _StatusChip(
                    label: 'Pending',
                    value: '${todos.where((t) => !t.completed).length}',
                    color: Color.lerp(accentColor, Colors.orange, 0.5)!,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                query.isStale ? '⚠️ Data is stale' : '✅ Data is fresh',
                style: TextStyle(
                  fontSize: 12,
                  color: query.isStale ? Colors.orange : Colors.green,
                ),
              ),
              if (query.dataUpdatedAt != null)
                Text(
                  'Updated: ${_formatTime(query.dataUpdatedAt!)}',
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? Colors.white38 : Colors.black26,
                  ),
                ),
            ],
          ),
        ),
        if (query.isRefetching) LinearProgressIndicator(color: accentColor),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: todos.length,
            itemBuilder: (context, index) {
              final todo = todos[index];
              return _TodoTile(todo: todo);
            },
          ),
        ),
      ],
    );
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);
    if (diff.inSeconds < 60) {
      return '${diff.inSeconds}s ago';
    } else if (diff.inMinutes < 60) {
      return '${diff.inMinutes}m ago';
    } else {
      return '${time.hour}:${time.minute.toString().padLeft(2, '0')}';
    }
  }
}

class _StatusChip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _StatusChip({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: isDark ? Colors.white54 : Colors.black45,
          ),
        ),
      ],
    );
  }
}

class _TodoTile extends StatelessWidget {
  final Todo todo;

  const _TodoTile({required this.todo});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accentColor = Theme.of(context).colorScheme.primary;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark
            ? Color.lerp(const Color(0xFF1A1A2E), accentColor, 0.04)
            : Color.lerp(Colors.white, accentColor, 0.02),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: accentColor.withAlpha(isDark ? 30 : 18)),
      ),
      child: Row(
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: todo.completed
                  ? accentColor.withAlpha(51)
                  : (isDark
                      ? Colors.white.withAlpha(26)
                      : Colors.black.withAlpha(13)),
              border: Border.all(
                color: todo.completed
                    ? accentColor
                    : (isDark ? Colors.white30 : Colors.black26),
                width: 2,
              ),
            ),
            child: todo.completed
                ? Icon(Icons.check, size: 14, color: accentColor)
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              todo.title,
              style: TextStyle(
                color: todo.completed
                    ? (isDark ? Colors.white54 : Colors.black38)
                    : (isDark ? Colors.white : Colors.black87),
                decoration: todo.completed ? TextDecoration.lineThrough : null,
              ),
            ),
          ),
          Text(
            '#${todo.id}',
            style: TextStyle(
              fontSize: 12,
              color: isDark ? Colors.white30 : Colors.black26,
            ),
          ),
        ],
      ),
    );
  }
}
