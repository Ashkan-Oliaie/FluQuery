import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:fluquery/fluquery.dart';
import '../../../api/api_client.dart';

/// Individual todo list item with per-item subtask count fetch
///
/// Each item has its own cached query - demonstrating how
/// FluQuery handles many individual queries efficiently.
class TodoListItem extends HookWidget {
  final Todo todo;
  final VoidCallback onTap;

  const TodoListItem({
    super.key,
    required this.todo,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // Per-item query for subtask count - each todo has its own cached query
    // This demonstrates:
    // 1. Query deduplication (same key = same query)
    // 2. Per-item caching (each todo.id gets its own cache entry)
    // 3. Stale time management (5 min before refetch)
    final subtasksQuery = useQuery<List<Subtask>, Object>(
      queryKey: ['subtasks', todo.id],
      queryFn: (_) => ApiClient.getSubtasks(todo.id),
      staleTime: const StaleTime(Duration(minutes: 5)),
    );

    final subtaskCount = subtasksQuery.data?.length ?? 0;
    final completedCount =
        subtasksQuery.data?.where((s) => s.completed).length ?? 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A2E),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0x1AFFFFFF)),
            ),
            child: Row(
              children: [
                // Completion indicator
                _CompletionBadge(completed: todo.completed),
                const SizedBox(width: 16),
                // Title and subtask info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        todo.title,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          decoration: todo.completed
                              ? TextDecoration.lineThrough
                              : null,
                        ),
                      ),
                      const SizedBox(height: 4),
                      _SubtaskInfo(
                        query: subtasksQuery,
                        completedCount: completedCount,
                        totalCount: subtaskCount,
                      ),
                    ],
                  ),
                ),
                // Arrow
                const Icon(Icons.chevron_right, color: Colors.white38),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CompletionBadge extends StatelessWidget {
  final bool completed;

  const _CompletionBadge({required this.completed});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: completed ? const Color(0xFF10B981) : Colors.transparent,
        border: Border.all(
          color: completed ? const Color(0xFF10B981) : Colors.white38,
          width: 2,
        ),
      ),
      child: completed
          ? const Icon(Icons.check, size: 16, color: Colors.white)
          : null,
    );
  }
}

class _SubtaskInfo extends StatelessWidget {
  final QueryResult<List<Subtask>, Object> query;
  final int completedCount;
  final int totalCount;

  const _SubtaskInfo({
    required this.query,
    required this.completedCount,
    required this.totalCount,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (query.isFetching && !query.hasData)
          const SizedBox(
            width: 12,
            height: 12,
            child: CircularProgressIndicator(strokeWidth: 1),
          )
        else
          Text(
            '$completedCount / $totalCount subtasks',
            style: TextStyle(
              color: Colors.white.withAlpha(128),
              fontSize: 12,
            ),
          ),
        if (query.isStale && query.hasData) ...[
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: const Color(0xFFF59E0B).withAlpha(51),
              borderRadius: BorderRadius.circular(4),
            ),
            child: const Text(
              'STALE',
              style: TextStyle(
                color: Color(0xFFF59E0B),
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
        if (query.isFetching && query.hasData) ...[
          const SizedBox(width: 8),
          const SizedBox(
            width: 10,
            height: 10,
            child: CircularProgressIndicator(strokeWidth: 1),
          ),
        ],
      ],
    );
  }
}
