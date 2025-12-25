import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:fluquery/fluquery.dart';
import '../api/api_client.dart';

class BasicQueryExample extends HookWidget {
  const BasicQueryExample({super.key});

  @override
  Widget build(BuildContext context) {
    final client = useQueryClient();
    
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
          // Invalidate button - marks data as stale and refetches
          IconButton(
            icon: const Icon(Icons.sync_problem),
            tooltip: 'Invalidate Cache',
            onPressed: () {
              client.invalidateQueries(queryKey: ['todos'], refetchType: true);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Cache invalidated - refetching...'),
                  duration: Duration(seconds: 1),
                ),
              );
            },
          ),
          // Refresh button
          IconButton(
            icon: todosQuery.isFetching
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh),
            tooltip: 'Refetch',
            onPressed: todosQuery.isFetching ? null : () => todosQuery.refetch(),
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
        child: _buildContent(context, todosQuery, client),
      ),
    );
  }

  Widget _buildContent(BuildContext context, QueryResult<List<Todo>, Object> query, QueryClient client) {
    if (query.isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text(
              'Loading todos...',
              style: TextStyle(color: Colors.white70),
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
            color: const Color(0xFF1A1A2E),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0x1AFFFFFF)),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _StatusChip(
                    label: 'Total',
                    value: '${todos.length}',
                    color: Colors.blue,
                  ),
                  _StatusChip(
                    label: 'Done',
                    value: '${todos.where((t) => t.completed).length}',
                    color: Colors.green,
                  ),
                  _StatusChip(
                    label: 'Pending',
                    value: '${todos.where((t) => !t.completed).length}',
                    color: Colors.orange,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Cache info
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
                    color: Colors.white.withAlpha(100),
                  ),
                ),
            ],
          ),
        ),
        // Background fetch indicator
        if (query.isRefetching) const LinearProgressIndicator(),
        // Todo list
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
            color: Colors.white.withAlpha(128),
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
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0x1AFFFFFF)),
      ),
      child: Row(
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: todo.completed
                  ? Colors.green.withAlpha(51)
                  : Colors.white.withAlpha(26),
              border: Border.all(
                color: todo.completed ? Colors.green : Colors.white30,
                width: 2,
              ),
            ),
            child: todo.completed
                ? const Icon(Icons.check, size: 14, color: Colors.green)
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              todo.title,
              style: TextStyle(
                color: todo.completed ? Colors.white54 : Colors.white,
                decoration: todo.completed ? TextDecoration.lineThrough : null,
              ),
            ),
          ),
          Text(
            '#${todo.id}',
            style: TextStyle(
              fontSize: 12,
              color: Colors.white.withAlpha(77),
            ),
          ),
        ],
      ),
    );
  }
}
