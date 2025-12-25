import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:fluquery/fluquery.dart';
import '../../api/api_client.dart';
import '../../constants/query_keys.dart';
import '../shared/shared.dart';
import 'widgets/info_banner.dart';
import 'widgets/optimistic_todos_list.dart';

class OptimisticUpdateExample extends HookWidget {
  const OptimisticUpdateExample({super.key});

  @override
  Widget build(BuildContext context) {
    final client = useQueryClient();
    final accentColor = Theme.of(context).colorScheme.primary;

    final todosQuery = useQuery<List<Todo>, Object>(
      queryKey: QueryKeys.todos,
      queryFn: (_) => ApiClient.getTodos(),
    );

    final toggleMutation =
        useMutation<Todo, Object, ({int id, bool completed}), List<Todo>>(
      mutationFn: (args) =>
          ApiClient.updateTodo(args.id, completed: args.completed),
      onMutate: (args) {
        client.cancelQueries(queryKey: QueryKeys.todos);
        final previousTodos =
            client.getQueryData<List<Todo>>(QueryKeys.todos) ?? [];
        final optimisticTodos = previousTodos.map((todo) {
          if (todo.id == args.id) {
            return todo.copyWith(completed: args.completed);
          }
          return todo;
        }).toList();
        client.setQueryData<List<Todo>>(QueryKeys.todos, optimisticTodos);
        return previousTodos;
      },
      onSuccess: (serverTodo, variables, previousTodos) {
        final currentTodos =
            client.getQueryData<List<Todo>>(QueryKeys.todos) ?? [];
        final updatedTodos = currentTodos.map((todo) {
          if (todo.id == serverTodo.id) {
            return serverTodo;
          }
          return todo;
        }).toList();
        client.setQueryData<List<Todo>>(QueryKeys.todos, updatedTodos);
      },
      onError: (error, variables, previousTodos) {
        if (previousTodos != null) {
          client.setQueryData<List<Todo>>(QueryKeys.todos, previousTodos);
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
            const InfoBanner(),
            Expanded(
              child: OptimisticTodosList(
                query: todosQuery,
                toggleMutation: toggleMutation,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
