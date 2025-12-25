import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:fluquery/fluquery.dart';
import '../api/api_client.dart';

class OptimisticUpdateExample extends HookWidget {
  const OptimisticUpdateExample({super.key});

  @override
  Widget build(BuildContext context) {
    final client = useQueryClient();

    // Fetch todos
    final todosQuery = useQuery<List<Todo>, Object>(
      queryKey: ['todos'],
      queryFn: (_) => ApiClient.getTodos(),
    );

    // Toggle mutation with optimistic update - TData, TError, TVariables, TContext
    final toggleMutation = useMutation<Todo, Object, ({int id, bool completed}), List<Todo>>(
      mutationFn: (args) => ApiClient.updateTodo(args.id, completed: args.completed),
      onMutate: (args) {
        // Cancel any outgoing refetches
        client.cancelQueries(queryKey: ['todos']);
        
        // Snapshot the previous value
        final previousTodos = client.getQueryData<List<Todo>>(['todos']) ?? [];
        
        // Optimistically update to the new value
        final optimisticTodos = previousTodos.map((todo) {
          if (todo.id == args.id) {
            return todo.copyWith(completed: args.completed);
          }
          return todo;
        }).toList();
        
        client.setQueryData<List<Todo>>(['todos'], optimisticTodos);
        
        return previousTodos; // Return context for rollback
      },
      onError: (error, variables, previousTodos) {
        // Rollback on error
        if (previousTodos != null) {
          client.setQueryData<List<Todo>>(['todos'], previousTodos);
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $error - Rolled back'), backgroundColor: Colors.red),
        );
      },
      onSettled: (data, error, variables, previousTodos) {
        // Refetch after mutation
        client.invalidateQueries(queryKey: ['todos']);
      },
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Optimistic Updates'),
        actions: [
          IconButton(
            icon: todosQuery.isFetching
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.refresh),
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
        child: Column(
          children: [
            // Info banner
            Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF8B5CF6).withAlpha(26),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF8B5CF6).withAlpha(77)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.flash_on, color: Color(0xFF8B5CF6)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Instant Updates', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        Text(
                          'Toggle items to see instant UI updates. If the server fails, changes are automatically rolled back.',
                          style: TextStyle(color: Colors.white.withAlpha(153), fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // List
            Expanded(child: _buildList(todosQuery, toggleMutation)),
          ],
        ),
      ),
    );
  }

  Widget _buildList(
    QueryResult<List<Todo>, Object> query,
    UseMutationResult<Todo, Object, ({int id, bool completed}), List<Todo>> toggleMutation,
  ) {
    if (query.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (query.isError) {
      return Center(child: Text('Error: ${query.error}', style: const TextStyle(color: Colors.red)));
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
    return GestureDetector(
      onTap: onToggle,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: todo.completed ? Colors.green.withAlpha(26) : const Color(0xFF1A1A2E),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: todo.completed ? Colors.green.withAlpha(77) : const Color(0x1AFFFFFF),
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
                color: todo.completed ? Colors.green : Colors.transparent,
                border: Border.all(
                  color: todo.completed ? Colors.green : Colors.white30,
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
                  color: todo.completed ? Colors.white54 : Colors.white,
                  decoration: todo.completed ? TextDecoration.lineThrough : null,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withAlpha(13),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text('#${todo.id}', style: TextStyle(fontSize: 12, color: Colors.white.withAlpha(77))),
            ),
          ],
        ),
      ),
    );
  }
}
