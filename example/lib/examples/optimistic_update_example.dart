import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:fluquery/fluquery.dart';
import '../api/api_client.dart';

class OptimisticUpdateExample extends HookWidget {
  const OptimisticUpdateExample({super.key});

  @override
  Widget build(BuildContext context) {
    final client = useQueryClient();
    final isDark = Theme.of(context).brightness == Brightness.dark;
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
        // Update cache with server response (contains authoritative data like timestamps)
        final currentTodos = client.getQueryData<List<Todo>>(['todos']) ?? [];
        final updatedTodos = currentTodos.map((todo) {
          if (todo.id == serverTodo.id) {
            return serverTodo; // Use server's version
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
              backgroundColor: Colors.red),
        );
      },
      // No onSettled - we handle everything in onSuccess/onError
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Optimistic Updates'),
        actions: [
          IconButton(
            icon: todosQuery.isFetching
                ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: accentColor),
                  )
                : const Icon(Icons.refresh),
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
        child: Column(
          children: [
            Container(
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
            ),
            Expanded(child: _buildList(context, todosQuery, toggleMutation)),
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
    final accentColor = Theme.of(context).colorScheme.primary;

    if (query.isLoading) {
      return Center(child: CircularProgressIndicator(color: accentColor));
    }

    if (query.isError) {
      return Center(
        child: Text('Error: ${query.error}',
            style: const TextStyle(color: Colors.red)),
      );
    }

    final todos = query.data ?? [];
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: todos.length,
      itemBuilder: (context, index) {
        final todo = todos[index];
        return _OptimisticTodoTile(
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

class _OptimisticTodoTile extends StatelessWidget {
  final Todo todo;
  final bool isUpdating;
  final VoidCallback onToggle;

  const _OptimisticTodoTile({
    required this.todo,
    required this.isUpdating,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accentColor = Theme.of(context).colorScheme.primary;

    return GestureDetector(
      onTap: onToggle,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: todo.completed
              ? accentColor.withAlpha(26)
              : (isDark
                  ? Color.lerp(const Color(0xFF1A1A2E), accentColor, 0.04)
                  : Color.lerp(Colors.white, accentColor, 0.02)),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: todo.completed
                ? accentColor.withAlpha(77) : accentColor.withAlpha(isDark ? 30 : 18),
          ),
        ),
        child: Row(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: todo.completed ? accentColor : Colors.transparent,
                border: Border.all(
                  color: todo.completed ? accentColor : (isDark ? Colors.white30 : Colors.black26),
                  width: 2,
                ),
              ),
              child: todo.completed
                  ? const Icon(Icons.check, size: 16, color: Colors.white)
                  : null,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                todo.title,
                style: TextStyle(
                  fontSize: 16,
                  color: todo.completed
                      ? (isDark ? Colors.white54 : Colors.black38)
                      : (isDark ? Colors.white : Colors.black87),
                  decoration:
                      todo.completed ? TextDecoration.lineThrough : null,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: accentColor.withAlpha(isDark ? 20 : 15),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                '#${todo.id}',
                style: TextStyle(fontSize: 12, color: accentColor.withAlpha(180)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
