import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:fluquery/fluquery.dart';
import '../../../api/api_client.dart';
import '../../../constants/query_keys.dart';
import '../../shared/shared.dart';
import '../models/request_log.dart';
import '../widgets/race_info_card.dart';
import '../widgets/request_history_card.dart';
import '../widgets/user_list.dart';

class SearchRaceConditionDemo extends HookWidget {
  const SearchRaceConditionDemo({super.key});

  @override
  Widget build(BuildContext context) {
    final searchController = useTextEditingController();
    final searchTerm = useState('');
    final client = useQueryClient();
    final requestHistory = useState<List<RequestLog>>([]);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accentColor = Theme.of(context).colorScheme.primary;

    final searchQuery = useQuery<List<User>, Object>(
      queryKey: QueryKeys.userSearchFor(searchTerm.value),
      queryFn: (ctx) async {
        final startTime = DateTime.now();
        final query = searchTerm.value;

        requestHistory.value = [
          ...requestHistory.value,
          RequestLog(
            query: query,
            startTime: startTime,
            status: RequestStatus.pending,
          ),
        ];

        try {
          final delay = Duration(
            milliseconds: 500 + (10 - query.length.clamp(0, 10)) * 100,
          );
          if (ctx.signal?.isCancelled == true) throw QueryCancelledException();
          await Future.delayed(delay);
          if (ctx.signal?.isCancelled == true) throw QueryCancelledException();

          final result = await ApiClient.searchUsers(query);
          updateLog(requestHistory, query, startTime, RequestStatus.success);
          return result;
        } on QueryCancelledException {
          updateLog(requestHistory, query, startTime, RequestStatus.cancelled);
          rethrow;
        } catch (e) {
          updateLog(requestHistory, query, startTime, RequestStatus.error);
          rethrow;
        }
      },
      enabled: searchTerm.value.isNotEmpty,
      staleTime: const StaleTime(Duration(seconds: 30)),
      retry: 0,
    );

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const RaceInfoCard(
            icon: Icons.search,
            title: 'Search-as-you-type',
            description:
                'Type quickly in the search box. Earlier requests are intentionally slower. '
                'Watch how FluQuery automatically discards stale results!',
          ),
          const SizedBox(height: 16),
          ThemedCard(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Icon(
                  Icons.search,
                  color: isDark ? Colors.white54 : Colors.black45,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: searchController,
                    style: TextStyle(
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Type to search users...',
                      hintStyle: TextStyle(
                        color: isDark ? Colors.white38 : Colors.black26,
                      ),
                      border: InputBorder.none,
                    ),
                    onChanged: (value) {
                      if (searchTerm.value.isNotEmpty) {
                        client.cancelQueries(
                          queryKey: QueryKeys.userSearchFor(searchTerm.value),
                        );
                      }
                      searchTerm.value = value;
                    },
                  ),
                ),
                if (searchQuery.isFetching) SmallSpinner(color: accentColor),
              ],
            ),
          ),
          const SizedBox(height: 16),
          RequestHistoryCard(history: requestHistory.value),
          const SizedBox(height: 16),
          _buildResults(context, searchQuery, searchTerm.value),
        ],
      ),
    );
  }

  Widget _buildResults(
    BuildContext context,
    QueryResult<List<User>, Object> query,
    String searchTerm,
  ) {
    final accentColor = Theme.of(context).colorScheme.primary;

    if (searchTerm.isEmpty) {
      return const EmptyState(
          icon: Icons.search, text: 'Start typing to search');
    }

    if (query.isLoading) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: CircularProgressIndicator(color: accentColor),
        ),
      );
    }

    if (query.isError) {
      if (query.error is QueryCancelledException) {
        return const EmptyState(
          icon: Icons.cancel_outlined,
          text: 'Query cancelled (newer search started)',
          color: Colors.orange,
        );
      }
      return EmptyState(
        icon: Icons.error_outline,
        text: 'Error: ${query.error}',
        color: Colors.red,
      );
    }

    final users = query.data ?? [];
    if (users.isEmpty) {
      return EmptyState(
        icon: Icons.person_off,
        text: 'No users found for "$searchTerm"',
      );
    }

    return UserList(users: users);
  }
}
