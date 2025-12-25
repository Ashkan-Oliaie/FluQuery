import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:fluquery/fluquery.dart';
import '../../api/api_client.dart';
import '../shared/shared.dart';
import 'widgets/optimistic_todo_tile.dart';

class OptimisticUpdateExample extends HookWidget {
  const OptimisticUpdateExample({super.key});

  @override
  Widget build(BuildContext context) {
    final client = useQueryClient();
    final accentColor = Theme.of(context).colorScheme.primary;

    final todosQuery = useQuery<List<Todo>, Object>(
      queryKey: ['todos'],
      queryFn: (_) => ApiClient.getTodos(),
    );

    final toggleMutation =
        useMutation<Todo, Object, ({int id, bool completed}), List<Todo>>(
      mutationFn: (args) =>
          ApiClient.updateTodo(args.id, completed: args.completed),
      onMutate: (args) {
        // Cancel any in-flight fetches to prevent race conditions
        client.cancelQueries(queryKey: ['todos']);

        // Snapshot previous state for rollback
        final previousTodos = client.getQueryData<List<Todo>>(['todos']) ?? [];

        // Optimistically update the cache
        final optimisticTodos = previousTodos.map((todo) {
          if (todo.id == args.id) {
            return todo.copyWith(completed: args.completed);
          }
          return todo;
        }).toList();
        client.setQueryData<List<Todo>>(['todos'], optimisticTodos);

        // Return previous state for potential rollback
        return previousTodos;
      },
      onSuccess: (serverTodo, variables, previousTodos) {
        // Update cache with server response (contains authoritative data)
        final currentTodos = client.getQueryData<List<Todo>>(['todos']) ?? [];
        final updatedTodos = currentTodos.map((todo) {
          if (todo.id == serverTodo.id) {
            return serverTodo;
          }
          return todo;
        }).toList();
        client.setQueryData<List<Todo>>(['todos'], updatedTodos);
      },
      onError: (error, variables, previousTodos) {
        // Rollback to previous state
        if (previousTodos != null) {
          client.setQueryData<List<Todo>>(['todos'], previousTodos);
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $error - Rolled back'),
            backgroundColor: Colors.red,
          ),
        );
      },
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Optimistic Updates'),
        actions: [
          IconButton(
            icon: todosQuery.isFetching
                ? SmallSpinner(color: accentColor)
                : const Icon(Icons.refresh),
            onPressed:
                todosQuery.isFetching ? null : () => todosQuery.refetch(),
          ),
        ],
      ),
      body: GradientBackground(
        child: Column(
          children: [
            _InfoBanner(),
            Expanded(
              child: _buildList(context, todosQuery, toggleMutation),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildList(
    BuildContext context,
    QueryResult<List<Todo>, Object> query,
    UseMutationResult<Todo, Object, ({int id, bool completed}), List<Todo>>
        toggleMutation,
  ) {
    if (query.isLoading) {
      return const LoadingIndicator();
    }

    if (query.isError) {
      return Center(
        child: Text(
          'Error: ${query.error}',
          style: const TextStyle(color: Colors.red),
        ),
      );
    }

    final todos = query.data ?? [];
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: todos.length,
      itemBuilder: (context, index) {
        final todo = todos[index];
        return OptimisticTodoTile(
          todo: todo,
          isUpdating: toggleMutation.isPending,
          onToggle: () {
            toggleMutation.mutate((id: todo.id, completed: !todo.completed));
          },
        );
      },
    );
  }
}

class _InfoBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accentColor = Theme.of(context).colorScheme.primary;

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: accentColor.withAlpha(26),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: accentColor.withAlpha(77)),
      ),
      child: Row(
        children: [
          Icon(Icons.flash_on, color: accentColor),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Instant Updates',
                  style: TextStyle(
                    color: isDark ? Colors.white : Colors.black87,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Toggle items to see instant UI updates. If the server fails, changes are automatically rolled back.',
                  style: TextStyle(
                    color: isDark ? Colors.white60 : Colors.black54,
                    fontSize: 12,
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
