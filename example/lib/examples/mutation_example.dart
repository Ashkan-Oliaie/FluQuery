import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:fluquery/fluquery.dart';
import '../api/api_client.dart';

class MutationExample extends HookWidget {
  const MutationExample({super.key});

  @override
  Widget build(BuildContext context) {
    final textController = useTextEditingController();
    final client = useQueryClient();

    // Fetch todos
    final todosQuery = useQuery<List<Todo>, Object>(
      queryKey: ['todos'],
      queryFn: (_) => ApiClient.getTodos(),
    );

    // Create mutation - 4 type params: TData, TError, TVariables, TContext
    final createMutation = useMutation<Todo, Object, String, void>(
      mutationFn: (title) => ApiClient.createTodo(title),
      onSuccess: (data, variables, ctx) {
        textController.clear();
        // Invalidate and refetch
        client.invalidateQueries(queryKey: ['todos'], refetchType: true);
      },
    );

    // Toggle mutation - track which item is being toggled via variables
    final toggleMutation = useMutation<Todo, Object, ({int id, bool completed}), void>(
      mutationFn: (args) => ApiClient.updateTodo(args.id, completed: args.completed),
      onSuccess: (data, variables, ctx) {
        client.invalidateQueries(queryKey: ['todos'], refetchType: true);
      },
    );

    // Delete mutation - track which item is being deleted via variables
    final deleteMutation = useMutation<void, Object, int, void>(
      mutationFn: (id) => ApiClient.deleteTodo(id),
      onSuccess: (data, variables, ctx) {
        client.invalidateQueries(queryKey: ['todos'], refetchType: true);
      },
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mutations'),
        actions: [
          if (todosQuery.isRefetching)
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
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
            // Add form
            Container(
              padding: const EdgeInsets.all(16),
              margin: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF1A1A2E),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0x1AFFFFFF)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: textController,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: 'Enter new todo...',
                        hintStyle: TextStyle(color: Colors.white.withAlpha(77)),
                        border: InputBorder.none,
                      ),
                      onSubmitted: (_) {
                        if (textController.text.isNotEmpty) {
                          createMutation.mutate(textController.text);
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: createMutation.isPending
                        ? null
                        : () {
                            if (textController.text.isNotEmpty) {
                              createMutation.mutate(textController.text);
                            }
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF6366F1),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    ),
                    child: createMutation.isPending
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.add),
                  ),
                ],
              ),
            ),
            // Error messages
            if (createMutation.isError)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  'Create failed: ${createMutation.error}',
                  style: const TextStyle(color: Colors.red),
                ),
              ),
            // List
            Expanded(
              child: _buildList(
                context,
                todosQuery,
                toggleMutation,
                deleteMutation,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildList(
    BuildContext context,
    QueryResult<List<Todo>, Object> query,
    UseMutationResult<Todo, Object, ({int id, bool completed}), void> toggleMutation,
    UseMutationResult<void, Object, int, void> deleteMutation,
  ) {
    if (query.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (query.isError) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Error: ${query.error}', style: const TextStyle(color: Colors.red)),
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
    
    if (todos.isEmpty) {
      return const Center(
        child: Text(
          'No todos yet. Add one above!',
          style: TextStyle(color: Colors.white54),
        ),
      );
    }
    
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: todos.length,
      itemBuilder: (context, index) {
        final todo = todos[index];
        
        // Check if THIS specific item is being toggled/deleted
        final isTogglingThis = toggleMutation.isPending && 
            toggleMutation.variables?.id == todo.id;
        final isDeletingThis = deleteMutation.isPending && 
            deleteMutation.variables == todo.id;
        
        return _TodoTile(
          todo: todo,
          onToggle: () => toggleMutation.mutate((id: todo.id, completed: !todo.completed)),
          onDelete: () => deleteMutation.mutate(todo.id),
          isToggling: isTogglingThis,
          isDeleting: isDeletingThis,
        );
      },
    );
  }
}

class _TodoTile extends StatelessWidget {
  final Todo todo;
  final VoidCallback onToggle;
  final VoidCallback onDelete;
  final bool isToggling;
  final bool isDeleting;

  const _TodoTile({
    required this.todo,
    required this.onToggle,
    required this.onDelete,
    required this.isToggling,
    required this.isDeleting,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 200),
      opacity: isDeleting ? 0.5 : 1.0,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A2E),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0x1AFFFFFF)),
        ),
        child: ListTile(
          leading: GestureDetector(
            onTap: isToggling ? null : onToggle,
            child: Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: todo.completed ? Colors.green.withAlpha(51) : Colors.white.withAlpha(26),
                border: Border.all(
                  color: todo.completed ? Colors.green : Colors.white30,
                  width: 2,
                ),
              ),
              child: isToggling
                  ? const Padding(
                      padding: EdgeInsets.all(4),
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : todo.completed
                      ? const Icon(Icons.check, size: 16, color: Colors.green)
                      : null,
            ),
          ),
          title: Text(
            todo.title,
            style: TextStyle(
              color: todo.completed ? Colors.white54 : Colors.white,
              decoration: todo.completed ? TextDecoration.lineThrough : null,
            ),
          ),
          subtitle: Text(
            '#${todo.id}',
            style: TextStyle(
              fontSize: 11,
              color: Colors.white.withAlpha(77),
            ),
          ),
          trailing: IconButton(
            icon: isDeleting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.red),
                  )
                : Icon(Icons.delete_outline, color: Colors.red.withAlpha(179)),
            onPressed: isDeleting ? null : onDelete,
          ),
        ),
      ),
    );
  }
}
