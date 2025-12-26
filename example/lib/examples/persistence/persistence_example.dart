import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:fluquery/fluquery.dart';

import '../../api/api_client.dart';
import '../../constants/query_keys.dart';
import '../shared/shared.dart';

/// Example demonstrating query persistence
///
/// This example shows how to:
/// 1. Configure a persister for the QueryClient
/// 2. Use the persist option on queries
/// 3. Hydrate cached data on app startup
/// 4. View persisted data status
class PersistenceExample extends HookWidget {
  const PersistenceExample({super.key});

  @override
  Widget build(BuildContext context) {
    final client = useQueryClient();

    // Query with persistence enabled
    final todosQuery = useQuery<List<Todo>, Object>(
      queryKey: QueryKeys.persistedTodos,
      queryFn: (_) => ApiClient.getTodos(),
      staleTime: const StaleTime(Duration(minutes: 5)),
      cacheTime: const CacheTime(Duration(hours: 1)),
      // Persistence configuration
      persist: PersistOptions<List<Todo>>(
        serializer: _TodoListSerializer(),
        maxAge: const Duration(minutes: 5),
      ),
    );

    return Scaffold(
      body: GradientBackground(
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(context),
              _buildPersistenceInfo(context, client),
              const SizedBox(height: 16),
              Expanded(
                child: _buildContent(context, todosQuery, client),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.storage_rounded,
                color: theme.colorScheme.primary,
                size: 28,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Query Persistence',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Data is saved to disk and restored on app restart. '
            'Try closing and reopening the app!',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPersistenceInfo(BuildContext context, QueryClient client) {
    final theme = Theme.of(context);
    final persister = client.persister;
    final isHydrated = client.isHydrated;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Icon(
            persister != null ? Icons.check_circle : Icons.error_outline,
            size: 16,
            color: persister != null ? theme.colorScheme.primary : theme.colorScheme.error,
          ),
          const SizedBox(width: 6),
          Text(
            persister != null
                ? 'Persister: Active${isHydrated ? ' • Hydrated' : ''}' : 'No persister',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    QueryResult<List<Todo>, Object> query,
    QueryClient client,
  ) {
    final theme = Theme.of(context);

    if (query.isLoading) {
      return const LoadingIndicator();
    }

    // Only show full error if we have NO data
    // If we have cached data, show it with an error indicator instead
    if (query.isError && !query.hasData) {
      return ErrorView(
        error: query.error,
        onRetry: query.refetch,
      );
    }

    final todos = query.data ?? [];

    return Column(
      children: [
        // Offline/error banner when we have cached data but refetch failed
        if (query.isRefetchError)
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: theme.colorScheme.errorContainer,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.cloud_off,
                  size: 16,
                  color: theme.colorScheme.onErrorContainer,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Showing cached data • Network unavailable',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onErrorContainer,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () => query.refetch(),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        if (query.isRefetchError) const SizedBox(height: 12),
        // Stats bar
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              StatChip(
                label: 'Items',
                value: '${todos.length}',
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 8),
              StatChip(
                label: 'Status',
                value: query.isRefetchError
                    ? 'Offline'
                    : query.isStale
                        ? 'Stale'
                        : 'Fresh',
                color: query.isRefetchError
                    ? theme.colorScheme.error
                    : query.isStale
                        ? Colors.orange
                        : theme.colorScheme.tertiary,
              ),
              const Spacer(),
              if (query.isFetching)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 12,
                        height: 12,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: theme.colorScheme.onPrimaryContainer,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Refreshing...',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onPrimaryContainer,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        // Action buttons
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => query.refetch(),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Refresh'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => client.invalidateQueries(
                    queryKey: QueryKeys.persistedTodos,
                    refetch: RefetchType.active,
                  ),
                  icon: const Icon(Icons.sync),
                  label: const Text('Invalidate'),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () async {
                await client.clearPersistence();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Persistence cleared'),
                      duration: Duration(seconds: 2),
                    ),
                  );
                }
              },
              icon: const Icon(Icons.delete_sweep),
              label: const Text('Clear Persisted Data'),
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.colorScheme.errorContainer,
                foregroundColor: theme.colorScheme.onErrorContainer,
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        // Todo list
        Expanded(
          child: todos.isEmpty
              ? const EmptyState(
                  icon: Icons.inbox_rounded,
                  text: 'No todos found',
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: todos.length,
                  itemBuilder: (context, index) {
                    final todo = todos[index];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: TodoTile(todo: todo),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

/// Custom serializer for Todo list
class _TodoListSerializer implements QueryDataSerializer<List<Todo>> {
  @override
  dynamic serialize(List<Todo> data) {
    return data.map((todo) => todo.toJson()).toList();
  }

  @override
  List<Todo> deserialize(dynamic json) {
    return (json as List).map((item) => Todo.fromJson(item as Map<String, dynamic>)).toList();
  }
}

