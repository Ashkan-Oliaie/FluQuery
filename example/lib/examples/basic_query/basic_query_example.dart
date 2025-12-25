import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:fluquery/fluquery.dart';
import '../../api/api_client.dart';
import '../../constants/query_keys.dart';
import '../shared/shared.dart';
import 'widgets/status_bar.dart';

class BasicQueryExample extends HookWidget {
  const BasicQueryExample({super.key});

  @override
  Widget build(BuildContext context) {
    final client = useQueryClient();
    final accentColor = Theme.of(context).colorScheme.primary;

    final todosQuery = useQuery<List<Todo>, Object>(
      queryKey: QueryKeys.todos,
      queryFn: (_) => ApiClient.getTodos(),
      staleTime: const StaleTime(Duration(minutes: 20)),
      retry: 3,
      cacheTime: CacheTime(Duration(seconds: 10)),
      refetchOnWindowFocus: true, // Remove from cache 10s after no observers
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
                queryKey: QueryKeys.todos,
                refetch: RefetchType.active,
              );
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
                ? SmallSpinner(color: accentColor)
                : const Icon(Icons.refresh),
            tooltip: 'Refetch',
            onPressed:
                todosQuery.isFetching ? null : () => todosQuery.refetch(),
          ),
        ],
      ),
      body: GradientBackground(
        child: _buildContent(context, todosQuery),
      ),
    );
  }

  Widget _buildContent(
      BuildContext context, QueryResult<List<Todo>, Object> query) {
    final accentColor = Theme.of(context).colorScheme.primary;

    if (query.isLoading) {
      return const LoadingIndicator(message: 'Loading todos...');
    }

    if (query.isError) {
      return ErrorView(error: query.error, onRetry: () => query.refetch());
    }

    final todos = query.data ?? [];
    final completed = todos.where((t) => t.completed).length;
    final pending = todos.where((t) => !t.completed).length;

    return Column(
      children: [
        StatusBar(
          total: todos.length,
          completed: completed,
          pending: pending,
          isStale: query.isStale,
          dataUpdatedAt: query.dataUpdatedAt,
        ),
        if (query.isRefetching) LinearProgressIndicator(color: accentColor),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: todos.length,
            itemBuilder: (context, index) => SimpleTodoTile(todo: todos[index]),
          ),
        ),
      ],
    );
  }
}
