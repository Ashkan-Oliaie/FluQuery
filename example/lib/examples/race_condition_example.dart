import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:fluquery/fluquery.dart';
import '../api/api_client.dart';

/// Race Condition Examples - demonstrates different scenarios
class RaceConditionExample extends HookWidget {
  const RaceConditionExample({super.key});

  @override
  Widget build(BuildContext context) {
    final tabController = useTabController(initialLength: 3);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Race Condition Handling'),
        bottom: TabBar(
          controller: tabController,
          tabs: const [
            Tab(icon: Icon(Icons.search), text: 'Search'),
            Tab(icon: Icon(Icons.filter_list), text: 'Filters'),
            Tab(icon: Icon(Icons.cancel), text: 'Cancellation'),
          ],
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF0F0F1A), Color(0xFF1A1A2E)],
          ),
        ),
        child: TabBarView(
          controller: tabController,
          children: const [
            _SearchRaceConditionDemo(),
            _FilterRaceConditionDemo(),
            _ManualCancellationDemo(),
          ],
        ),
      ),
    );
  }
}

/// Tab 1: Search-as-you-type race condition demo
class _SearchRaceConditionDemo extends HookWidget {
  const _SearchRaceConditionDemo();

  @override
  Widget build(BuildContext context) {
    final searchController = useTextEditingController();
    final searchTerm = useState('');
    final client = useQueryClient();
    final requestHistory = useState<List<_RequestLog>>([]);

    final searchQuery = useQuery<List<User>, Object>(
      queryKey: ['users', 'search', searchTerm.value],
      queryFn: (ctx) async {
        final startTime = DateTime.now();
        final query = searchTerm.value;
        
        requestHistory.value = [
          ...requestHistory.value,
          _RequestLog(query: query, startTime: startTime, status: _Status.pending),
        ];
        
        try {
          // Shorter queries are slower (race condition demo)
          final delay = Duration(milliseconds: 500 + (10 - query.length.clamp(0, 10)) * 100);
          
          if (ctx.signal?.isCancelled == true) throw QueryCancelledException();
          await Future.delayed(delay);
          if (ctx.signal?.isCancelled == true) throw QueryCancelledException();
          
          final result = await ApiClient.searchUsers(query);
          _updateLog(requestHistory, query, startTime, _Status.success);
          return result;
        } on QueryCancelledException {
          _updateLog(requestHistory, query, startTime, _Status.cancelled);
          rethrow;
        } catch (e) {
          _updateLog(requestHistory, query, startTime, _Status.error);
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
          _InfoCard(
            icon: Icons.search,
            title: 'Search-as-you-type',
            description:
                'Type quickly in the search box. Earlier requests are intentionally slower. '
                'Watch how FluQuery automatically discards stale results!',
          ),
          const SizedBox(height: 16),

          // Search input
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A2E),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0x1AFFFFFF)),
            ),
            child: Row(
              children: [
                const Icon(Icons.search, color: Colors.white54),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: searchController,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      hintText: 'Type to search users...',
                      hintStyle: TextStyle(color: Colors.white38),
                      border: InputBorder.none,
                    ),
                    onChanged: (value) {
                      if (searchTerm.value.isNotEmpty) {
                        client.cancelQueries(
                          queryKey: ['users', 'search', searchTerm.value],
                        );
                      }
                      searchTerm.value = value;
                    },
                  ),
                ),
                if (searchQuery.isFetching)
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Request history
          _RequestHistoryCard(history: requestHistory.value),
          const SizedBox(height: 16),

          // Results
          _buildResults(searchQuery, searchTerm.value),
        ],
      ),
    );
  }

  Widget _buildResults(QueryResult<List<User>, Object> query, String searchTerm) {
    if (searchTerm.isEmpty) {
      return const _EmptyState(
        icon: Icons.search,
        text: 'Start typing to search',
      );
    }

    if (query.isLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (query.isError) {
      if (query.error is QueryCancelledException) {
        return const _EmptyState(
          icon: Icons.cancel_outlined,
          text: 'Query cancelled (newer search started)',
          color: Colors.orange,
        );
      }
      return _EmptyState(
        icon: Icons.error_outline,
        text: 'Error: ${query.error}',
        color: Colors.red,
      );
    }

    final users = query.data ?? [];
    if (users.isEmpty) {
      return _EmptyState(
        icon: Icons.person_off,
        text: 'No users found for "$searchTerm"',
      );
    }

    return _UserList(users: users);
  }
}

/// Tab 2: Filter change race condition demo
class _FilterRaceConditionDemo extends HookWidget {
  const _FilterRaceConditionDemo();

  @override
  Widget build(BuildContext context) {
    final selectedFilter = useState<String>('all');
    final client = useQueryClient();

    final todosQuery = useQuery<List<Todo>, Object>(
      queryKey: ['todos', 'filtered', selectedFilter.value],
      queryFn: (ctx) async {
        // Simulate variable response times based on filter
        final delays = {'all': 800, 'completed': 400, 'pending': 1200};
        await Future.delayed(Duration(milliseconds: delays[selectedFilter.value] ?? 500));
        
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
          _InfoCard(
            icon: Icons.filter_list,
            title: 'Filter Switching',
            description:
                'Rapidly switch between filters. Different filters have different response times. '
                'With keepPreviousData, the UI stays responsive!',
          ),
          const SizedBox(height: 16),

          // Filter buttons
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A2E),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0x1AFFFFFF)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Filter:', style: TextStyle(color: Colors.white70)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _FilterChip(
                      label: 'All (800ms)',
                      isSelected: selectedFilter.value == 'all',
                      onTap: () {
                        client.cancelQueries(queryKey: ['todos', 'filtered']);
                        selectedFilter.value = 'all';
                      },
                    ),
                    const SizedBox(width: 8),
                    _FilterChip(
                      label: 'Done (400ms)',
                      isSelected: selectedFilter.value == 'completed',
                      onTap: () {
                        client.cancelQueries(queryKey: ['todos', 'filtered']);
                        selectedFilter.value = 'completed';
                      },
                    ),
                    const SizedBox(width: 8),
                    _FilterChip(
                      label: 'Pending (1200ms)',
                      isSelected: selectedFilter.value == 'pending',
                      onTap: () {
                        client.cancelQueries(queryKey: ['todos', 'filtered']);
                        selectedFilter.value = 'pending';
                      },
                    ),
                  ],
                ),
                if (todosQuery.isPreviousData)
                  const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: Text(
                      '📍 Showing previous data while loading...',
                      style: TextStyle(color: Colors.orange, fontSize: 11),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Results
          if (todosQuery.isLoading && !todosQuery.isPreviousData)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: CircularProgressIndicator(),
              ),
            )
          else
            Opacity(
              opacity: todosQuery.isPreviousData ? 0.6 : 1.0,
              child: _TodoList(
                todos: todosQuery.data ?? [],
                isFetching: todosQuery.isFetching,
              ),
            ),
        ],
      ),
    );
  }
}

/// Tab 3: Manual cancellation demo
class _ManualCancellationDemo extends HookWidget {
  const _ManualCancellationDemo();

  @override
  Widget build(BuildContext context) {
    final client = useQueryClient();
    final requestKey = useState(0);

    final slowQuery = useQuery<String, Object>(
      queryKey: ['slow-query', requestKey.value],
      queryFn: (ctx) async {
        for (int i = 0; i < 10; i++) {
          if (ctx.signal?.isCancelled == true) {
            throw QueryCancelledException();
          }
          await Future.delayed(const Duration(seconds: 1));
        }
        return 'Completed after 10 seconds!';
      },
      enabled: requestKey.value > 0,
      retry: 0,
    );

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _InfoCard(
            icon: Icons.cancel,
            title: 'Manual Cancellation',
            description:
                'Start a slow query (10 seconds) and cancel it before completion. '
                'Use CancellationToken to check if the query should stop.',
          ),
          const SizedBox(height: 24),

          // Control buttons
          Center(
            child: Column(
              children: [
                ElevatedButton.icon(
                  onPressed: slowQuery.isFetching
                      ? null
                      : () => requestKey.value++,
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('Start 10s Query'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: slowQuery.isFetching
                      ? () => client.cancelQueries(
                            queryKey: ['slow-query', requestKey.value],
                          )
                      : null,
                  icon: const Icon(Icons.cancel),
                  label: const Text('Cancel Query'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),

          // Status
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A2E),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0x1AFFFFFF)),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      slowQuery.isFetching
                          ? Icons.hourglass_empty
                          : slowQuery.isSuccess
                              ? Icons.check_circle
                              : slowQuery.isError
                                  ? Icons.error
                                  : Icons.radio_button_unchecked,
                      color: slowQuery.isFetching
                          ? Colors.blue
                          : slowQuery.isSuccess
                              ? Colors.green
                              : slowQuery.isError
                                  ? Colors.red
                                  : Colors.white38,
                      size: 48,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  slowQuery.isFetching
                      ? 'Running... (click Cancel to stop)'
                      : slowQuery.isSuccess
                          ? slowQuery.data ?? 'Done!'
                          : slowQuery.isError
                              ? slowQuery.error is QueryCancelledException
                                  ? 'Cancelled by user!'
                                  : 'Error: ${slowQuery.error}'
                              : 'Click Start to begin',
                  style: TextStyle(
                    color: slowQuery.isFetching
                        ? Colors.blue
                        : slowQuery.isSuccess
                            ? Colors.green
                            : slowQuery.isError
                                ? Colors.orange
                                : Colors.white54,
                    fontSize: 16,
                  ),
                  textAlign: TextAlign.center,
                ),
                if (slowQuery.isFetching) ...[
                  const SizedBox(height: 16),
                  const LinearProgressIndicator(),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ============ Helper Widgets ============

void _updateLog(
  ValueNotifier<List<_RequestLog>> history,
  String query,
  DateTime startTime,
  _Status status,
) {
  history.value = history.value.map((log) {
    if (log.query == query && log.startTime == startTime) {
      return log.copyWith(status: status, endTime: DateTime.now());
    }
    return log;
  }).toList();
}

enum _Status { pending, success, cancelled, error }

class _RequestLog {
  final String query;
  final DateTime startTime;
  final DateTime? endTime;
  final _Status status;

  _RequestLog({
    required this.query,
    required this.startTime,
    this.endTime,
    required this.status,
  });

  _RequestLog copyWith({DateTime? endTime, _Status? status}) {
    return _RequestLog(
      query: query,
      startTime: startTime,
      endTime: endTime ?? this.endTime,
      status: status ?? this.status,
    );
  }

  Duration? get duration => endTime?.difference(startTime);
}

class _RequestHistoryCard extends StatelessWidget {
  final List<_RequestLog> history;

  const _RequestHistoryCard({required this.history});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0x1AFFFFFF)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Request History',
            style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold, fontSize: 12),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 80,
            child: history.isEmpty
                ? const Center(
                    child: Text('Type to see requests...', style: TextStyle(color: Colors.white38)),
                  )
                : ListView.builder(
                    reverse: true,
                    itemCount: history.length,
                    itemBuilder: (context, index) {
                      final log = history[history.length - 1 - index];
                      final color = switch (log.status) {
                        _Status.pending => Colors.blue,
                        _Status.success => Colors.green,
                        _Status.cancelled => Colors.orange,
                        _Status.error => Colors.red,
                      };
                      final icon = switch (log.status) {
                        _Status.pending => Icons.hourglass_empty,
                        _Status.success => Icons.check_circle,
                        _Status.cancelled => Icons.cancel,
                        _Status.error => Icons.error,
                      };
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Row(
                          children: [
                            Icon(icon, size: 14, color: color),
                            const SizedBox(width: 8),
                            Text('"${log.query}"', style: TextStyle(color: color, fontSize: 12)),
                            const Spacer(),
                            if (log.duration != null)
                              Text(
                                '${log.duration!.inMilliseconds}ms',
                                style: TextStyle(color: Colors.white.withAlpha(128), fontSize: 10),
                              ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;

  const _InfoCard({required this.icon, required this.title, required this.description});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E3A5F),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.withAlpha(77)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: Colors.blue, size: 20),
              const SizedBox(width: 8),
              Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 8),
          Text(description, style: const TextStyle(color: Colors.white70, fontSize: 12)),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color;

  const _EmptyState({required this.icon, required this.text, this.color = Colors.white54});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          children: [
            Icon(icon, size: 48, color: color.withAlpha(128)),
            const SizedBox(height: 16),
            Text(text, style: TextStyle(color: color), textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

class _UserList extends StatelessWidget {
  final List<User> users;

  const _UserList({required this.users});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: users.map((user) {
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A2E),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0x1AFFFFFF)),
          ),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: Colors.primaries[user.id % Colors.primaries.length],
                radius: 20,
                child: Text(user.name[0], style: const TextStyle(color: Colors.white)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(user.name, style: const TextStyle(color: Colors.white)),
                    Text(user.email, style: TextStyle(color: Colors.white.withAlpha(128), fontSize: 12)),
                  ],
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

class _TodoList extends StatelessWidget {
  final List<Todo> todos;
  final bool isFetching;

  const _TodoList({required this.todos, this.isFetching = false});

  @override
  Widget build(BuildContext context) {
    if (todos.isEmpty) {
      return const _EmptyState(icon: Icons.inbox, text: 'No todos');
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('${todos.length} items', style: const TextStyle(color: Colors.white54, fontSize: 12)),
            if (isFetching) ...[
              const SizedBox(width: 8),
              const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2)),
            ],
          ],
        ),
        const SizedBox(height: 8),
        ...todos.take(5).map((todo) {
          return Container(
            margin: const EdgeInsets.only(bottom: 4),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A2E),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0x1AFFFFFF)),
            ),
            child: Row(
              children: [
                Icon(
                  todo.completed ? Icons.check_circle : Icons.radio_button_unchecked,
                  color: todo.completed ? Colors.green : Colors.white38,
                  size: 16,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    todo.title,
                    style: TextStyle(
                      color: todo.completed ? Colors.white54 : Colors.white,
                      fontSize: 12,
                      decoration: todo.completed ? TextDecoration.lineThrough : null,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          );
        }),
        if (todos.length > 5)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              '+ ${todos.length - 5} more...',
              style: const TextStyle(color: Colors.white38, fontSize: 11),
            ),
          ),
      ],
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _FilterChip({required this.label, required this.isSelected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? Colors.blue : Colors.white.withAlpha(26),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.white70,
            fontSize: 11,
          ),
        ),
      ),
    );
  }
}

