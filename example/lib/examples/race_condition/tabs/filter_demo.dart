import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:fluquery/fluquery.dart';
import '../../../api/api_client.dart';
import '../../../constants/query_keys.dart';
import '../../shared/shared.dart';
import '../widgets/race_info_card.dart';
import '../widgets/todo_list.dart';
import '../widgets/filter_chip.dart';

class FilterRaceConditionDemo extends HookWidget {
  const FilterRaceConditionDemo({super.key});

  @override
  Widget build(BuildContext context) {
    final selectedFilter = useState<String>('all');
    final client = useQueryClient();
    final accentColor = Theme.of(context).colorScheme.primary;

    final todosQuery = useQuery<List<Todo>, Object>(
      queryKey: QueryKeys.todosFilteredFor(selectedFilter.value),
      queryFn: (ctx) async {
        final delays = {'all': 800, 'completed': 400, 'pending': 1200};
        await Future.delayed(
          Duration(milliseconds: delays[selectedFilter.value] ?? 500),
        );
        if (ctx.signal?.isCancelled == true) throw QueryCancelledException();

        final todos = await ApiClient.getTodos();
        return switch (selectedFilter.value) {
          'completed' => todos.where((t) => t.completed).toList(),
          'pending' => todos.where((t) => !t.completed).toList(),
          _ => todos,
        };
      },
      keepPreviousData: true,
      retry: 0,
    );

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const RaceInfoCard(
            icon: Icons.filter_list,
            title: 'Filter Switching',
            description:
                'Rapidly switch between filters. Different filters have different response times. '
                'With keepPreviousData, the UI stays responsive!',
          ),
          const SizedBox(height: 16),
          ThemedCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Filter:',
                  style: TextStyle(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Colors.white70
                        : Colors.black54,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    RaceFilterChip(
                      label: 'All (800ms)',
                      isSelected: selectedFilter.value == 'all',
                      onTap: () {
                        client.cancelQueries(queryKey: QueryKeys.todosFiltered);
                        selectedFilter.value = 'all';
                      },
                    ),
                    const SizedBox(width: 8),
                    RaceFilterChip(
                      label: 'Done (400ms)',
                      isSelected: selectedFilter.value == 'completed',
                      onTap: () {
                        client.cancelQueries(queryKey: QueryKeys.todosFiltered);
                        selectedFilter.value = 'completed';
                      },
                    ),
                    const SizedBox(width: 8),
                    RaceFilterChip(
                      label: 'Pending (1200ms)',
                      isSelected: selectedFilter.value == 'pending',
                      onTap: () {
                        client.cancelQueries(queryKey: QueryKeys.todosFiltered);
                        selectedFilter.value = 'pending';
                      },
                    ),
                  ],
                ),
                if (todosQuery.isPreviousData)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      '📍 Showing previous data while loading...',
                      style: TextStyle(color: accentColor, fontSize: 11),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (todosQuery.isLoading && !todosQuery.isPreviousData)
            const LoadingIndicator()
          else
            Opacity(
              opacity: todosQuery.isPreviousData ? 0.6 : 1.0,
              child: RaceTodoList(
                todos: todosQuery.data ?? [],
                isFetching: todosQuery.isFetching,
              ),
            ),
        ],
      ),
    );
  }
}
