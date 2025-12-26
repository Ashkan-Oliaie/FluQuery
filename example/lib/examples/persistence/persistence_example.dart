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
        maxAge: const Duration(days: 7),
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
              color: theme.colorScheme.onSurface.withOpacity(0.7),
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
      child: ThemedCard(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    color: theme.colorScheme.primary,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Persistence Status',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _StatusRow(
                label: 'Persister',
                value: persister != null ? 'Configured ✓' : 'Not configured',
                isActive: persister != null,
              ),
              const SizedBox(height: 8),
              _StatusRow(
                label: 'Cache Hydrated',
                value: isHydrated ? 'Yes ✓' : 'No',
                isActive: isHydrated,
              ),
              const SizedBox(height: 12),
                Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest
                      .withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.lightbulb_outline,
                      size: 16,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        persister != null
                            ? 'Using HiveCePersister - data saved to device storage. '
                                'Close and reopen the app to see cached data restored!'
                            : 'No persister configured. Add HiveCePersister to QueryClient.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
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

    if (query.isError) {
      return ErrorView(
        error: query.error,
        onRetry: query.refetch,
      );
    }

    final todos = query.data ?? [];

    return Column(
      children: [
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
                value: query.isStale ? 'Stale' : 'Fresh',
                color:
                    query.isStale ? Colors.orange : theme.colorScheme.tertiary,
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

class _StatusRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isActive;

  const _StatusRow({
    required this.label,
    required this.value,
    required this.isActive,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurface.withOpacity(0.7),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: isActive
                ? theme.colorScheme.primaryContainer
                : theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            value,
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w600,
              color: isActive
                  ? theme.colorScheme.onPrimaryContainer
                  : theme.colorScheme.onSurface.withOpacity(0.6),
            ),
          ),
        ),
      ],
    );
  }
}

/// Custom serializer for List<Todo>
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

