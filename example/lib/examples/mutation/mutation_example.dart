import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:fluquery/fluquery.dart';
import '../../api/api_client.dart';
import '../shared/shared.dart';

class MutationExample extends HookWidget {
  const MutationExample({super.key});

  @override
  Widget build(BuildContext context) {
    final textController = useTextEditingController();
    final client = useQueryClient();
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
          queryKey: ['todos'],
          refetch: RefetchType.active,
        );
      },
    );

    final toggleMutation = useMutation<Todo, Object, ({int id, bool completed}), void>(
      mutationFn: (args) => ApiClient.updateTodo(args.id, completed: args.completed),
      onSuccess: (data, variables, ctx) {
        client.invalidateQueries(
          queryKey: ['todos'],
          refetch: RefetchType.active,
        );
      },
    );

    final deleteMutation = useMutation<void, Object, int, void>(
      mutationFn: (id) => ApiClient.deleteTodo(id),
      onSuccess: (data, variables, ctx) {
        client.invalidateQueries(
          queryKey: ['todos'],
          refetch: RefetchType.active,
        );
      },
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mutations'),
        actions: [
          if (todosQuery.isRefetching)
            Padding(
              padding: const EdgeInsets.all(16),
              child: SmallSpinner(color: accentColor),
            ),
        ],
      ),
      body: GradientBackground(
        child: Column(
          children: [
            _AddTodoForm(
              controller: textController,
              isPending: createMutation.isPending,
              error: createMutation.error,
              onSubmit: () {
                if (textController.text.isNotEmpty) {
                  createMutation.mutate(textController.text);
                }
              },
            ),
            Expanded(
              child: _TodoList(
                query: todosQuery,
                toggleMutation: toggleMutation,
                deleteMutation: deleteMutation,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AddTodoForm extends StatelessWidget {
  final TextEditingController controller;
  final bool isPending;
  final Object? error;
  final VoidCallback onSubmit;

  const _AddTodoForm({
    required this.controller,
    required this.isPending,
    required this.error,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accentColor = Theme.of(context).colorScheme.primary;

    return Column(
      children: [
        ThemedCard(
          elevated: true,
          margin: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                  decoration: InputDecoration(
                    hintText: 'Enter new todo...',
                    hintStyle: TextStyle(
                      color: isDark ? Colors.white30 : Colors.black26,
                    ),
                    border: InputBorder.none,
                  ),
                  onSubmitted: (_) => onSubmit(),
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton(
                onPressed: isPending ? null : onSubmit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: accentColor,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                ),
                child: isPending
                    ? const SmallSpinner(color: Colors.white)
                    : const Icon(Icons.add),
              ),
            ],
          ),
        ),
        if (error != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'Create failed: $error',
              style: const TextStyle(color: Colors.red),
            ),
          ),
      ],
    );
  }
}

class _TodoList extends StatelessWidget {
  final QueryResult<List<Todo>, Object> query;
  final UseMutationResult<Todo, Object, ({int id, bool completed}), void> toggleMutation;
  final UseMutationResult<void, Object, int, void> deleteMutation;

  const _TodoList({
    required this.query,
    required this.toggleMutation,
    required this.deleteMutation,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (query.isLoading) {
      return const LoadingIndicator();
    }

    if (query.isError) {
      return ErrorView(error: query.error, onRetry: () => query.refetch());
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

        return TodoTile(
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

