import 'package:flutter/material.dart';
import 'package:fluquery/fluquery.dart';
import '../../../api/api_client.dart';
import '../../shared/shared.dart';

class MutationTodoList extends StatelessWidget {
  final QueryResult<List<Todo>, Object> query;
  final UseMutationResult<Todo, Object, ({int id, bool completed}), void>
      toggleMutation;
  final UseMutationResult<void, Object, int, void> deleteMutation;

  const MutationTodoList({
    super.key,
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
          onToggle: () => toggleMutation.mutate(
            (id: todo.id, completed: !todo.completed),
          ),
          onDelete: () => deleteMutation.mutate(todo.id),
          isToggling: isTogglingThis,
          isDeleting: isDeletingThis,
        );
      },
    );
  }
}
