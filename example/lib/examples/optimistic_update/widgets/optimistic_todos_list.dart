import 'package:flutter/material.dart';
import 'package:fluquery/fluquery.dart';
import '../../../api/api_client.dart';
import '../../shared/shared.dart';
import 'optimistic_todo_tile.dart';

class OptimisticTodosList extends StatelessWidget {
  final QueryResult<List<Todo>, Object> query;
  final UseMutationResult<Todo, Object, ({int id, bool completed}), List<Todo>>
      toggleMutation;

  const OptimisticTodosList({
    super.key,
    required this.query,
    required this.toggleMutation,
  });

  @override
  Widget build(BuildContext context) {
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
