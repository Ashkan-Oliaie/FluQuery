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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accentColor = Theme.of(context).colorScheme.primary;

    final todosQuery = useQuery<List<Todo>, Object>(
      queryKey: ['todos'],
      queryFn: (_) => ApiClient.getTodos(),
    );

    final createMutation = useMutation<Todo, Object, String, void>(
      mutationFn: (title) => ApiClient.createTodo(title),
      onSuccess: (data, variables, ctx) {
        textController.clear();
        client.invalidateQueries(
            queryKey: ['todos'], refetch: RefetchType.active);
      },
    );

    final toggleMutation =
        useMutation<Todo, Object, ({int id, bool completed}), void>(
      mutationFn: (args) =>
          ApiClient.updateTodo(args.id, completed: args.completed),
      onSuccess: (data, variables, ctx) {
        client.invalidateQueries(
            queryKey: ['todos'], refetch: RefetchType.active);
      },
    );

    final deleteMutation = useMutation<void, Object, int, void>(
      mutationFn: (id) => ApiClient.deleteTodo(id),
      onSuccess: (data, variables, ctx) {
        client.invalidateQueries(
            queryKey: ['todos'], refetch: RefetchType.active);
      },
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mutations'),
        actions: [
          if (todosQuery.isRefetching)
            Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: accentColor),
              ),
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
            // Add form
            Container(
              padding: const EdgeInsets.all(16),
              margin: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark
                    ? Color.lerp(const Color(0xFF1A1A2E), accentColor, 0.05)
                    : Color.lerp(Colors.white, accentColor, 0.03),
                borderRadius: BorderRadius.circular(12),
                border:
                    Border.all(color: accentColor.withAlpha(isDark ? 40 : 25)),
                boxShadow: [
                  BoxShadow(
                    color: accentColor.withAlpha(isDark ? 15 : 20),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: textController,
                      style: TextStyle(
                          color: isDark ? Colors.white : Colors.black87),
                      decoration: InputDecoration(
                        hintText: 'Enter new todo...',
                        hintStyle: TextStyle(
                            color: isDark ? Colors.white30 : Colors.black26),
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
                      backgroundColor: accentColor,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 12),
                    ),
                    child: createMutation.isPending
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.add),
                  ),
                ],
              ),
            ),
            if (createMutation.isError)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  'Create failed: ${createMutation.error}',
                  style: const TextStyle(color: Colors.red),
                ),
              ),
            Expanded(
              child: _buildList(
                  context, todosQuery, toggleMutation, deleteMutation),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildList(
    BuildContext context,
    QueryResult<List<Todo>, Object> query,
    UseMutationResult<Todo, Object, ({int id, bool completed}), void>
        toggleMutation,
    UseMutationResult<void, Object, int, void> deleteMutation,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accentColor = Theme.of(context).colorScheme.primary;

    if (query.isLoading) {
      return Center(child: CircularProgressIndicator(color: accentColor));
    }

    if (query.isError) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Error: ${query.error}',
                style: const TextStyle(color: Colors.red)),
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

    if (todos.isEmpty) {
      return Center(
        child: Text(
          'No todos yet. Add one above!',
          style: TextStyle(color: isDark ? Colors.white54 : Colors.black45),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: todos.length,
      itemBuilder: (context, index) {
        final todo = todos[index];
        final isTogglingThis =
            toggleMutation.isPending && toggleMutation.variables?.id == todo.id;
        final isDeletingThis =
            deleteMutation.isPending && deleteMutation.variables == todo.id;

        return _TodoTile(
          todo: todo,
          onToggle: () =>
              toggleMutation.mutate((id: todo.id, completed: !todo.completed)),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accentColor = Theme.of(context).colorScheme.primary;

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 200),
      opacity: isDeleting ? 0.5 : 1.0,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: isDark
              ? Color.lerp(const Color(0xFF1A1A2E), accentColor, 0.04)
              : Color.lerp(Colors.white, accentColor, 0.02),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: accentColor.withAlpha(isDark ? 30 : 18)),
        ),
        child: ListTile(
          leading: GestureDetector(
            onTap: isToggling ? null : onToggle,
            child: Container(
              width: 28,
              height: 28,
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
              child: isToggling
                  ? Padding(
                      padding: const EdgeInsets.all(4),
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: accentColor),
                    )
                  : todo.completed
                      ? Icon(Icons.check, size: 16, color: accentColor)
                      : null,
            ),
          ),
          title: Text(
            todo.title,
            style: TextStyle(
              color: todo.completed
                  ? (isDark ? Colors.white54 : Colors.black38)
                  : (isDark ? Colors.white : Colors.black87),
              decoration: todo.completed ? TextDecoration.lineThrough : null,
            ),
          ),
          subtitle: Text(
            '#${todo.id}',
            style: TextStyle(
              fontSize: 11,
              color: isDark ? Colors.white30 : Colors.black26,
            ),
          ),
          trailing: IconButton(
            icon: isDeleting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.red),
                  )
                : Icon(Icons.delete_outline, color: Colors.red.withAlpha(179)),
            onPressed: isDeleting ? null : onDelete,
          ),
        ),
      ),
    );
  }
}
