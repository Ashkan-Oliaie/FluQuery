import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:fluquery/fluquery.dart';
import '../../api/api_client.dart';
import '../../constants/query_keys.dart';
import '../shared/shared.dart';
import 'widgets/add_todo_form.dart';
import 'widgets/mutation_todo_list.dart';

class MutationExample extends HookWidget {
  const MutationExample({super.key});

  @override
  Widget build(BuildContext context) {
    final textController = useTextEditingController();
    final client = useQueryClient();
    final accentColor = Theme.of(context).colorScheme.primary;

    final todosQuery = useQuery<List<Todo>, Object>(
      queryKey: QueryKeys.todos,
      queryFn: (_) => ApiClient.getTodos(),
      staleTime: const StaleTime(Duration(seconds: 10)),
      refetchInterval: Duration(seconds: 10),
    );

    final createMutation = useMutation<Todo, Object, String, void>(
      mutationFn: (title) => ApiClient.createTodo(title),
      onSuccess: (data, variables, ctx) {
        textController.clear();
        client.invalidateQueries(
          queryKey: QueryKeys.todos,
          refetch: RefetchType.active,
        );
      },
    );

    final toggleMutation =
        useMutation<Todo, Object, ({int id, bool completed}), void>(
      mutationFn: (args) =>
          ApiClient.updateTodo(args.id, completed: args.completed),
      onSuccess: (data, variables, ctx) {
        client.invalidateQueries(
          queryKey: QueryKeys.todos,
          refetch: RefetchType.active,
        );
      },
    );

    final deleteMutation = useMutation<void, Object, int, void>(
      mutationFn: (id) => ApiClient.deleteTodo(id),
      onSuccess: (data, variables, ctx) {
        client.invalidateQueries(
          queryKey: QueryKeys.todos,
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
            AddTodoForm(
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
              child: MutationTodoList(
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
