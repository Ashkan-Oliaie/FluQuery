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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accentColor = Theme.of(context).colorScheme.primary;

    // Per-item query for subtask count - each todo has its own cached query
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
              // Card background gets a subtle tint from global accent
              color: isDark
                  ? Color.lerp(const Color(0xFF1A1A2E), accentColor, 0.05)
                  : Color.lerp(Colors.white, accentColor, 0.02),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isDark
                    ? accentColor.withAlpha(35)
                    : accentColor.withAlpha(20),
              ),
              boxShadow: [
                BoxShadow(
                  color: accentColor.withAlpha(isDark ? 12 : 15),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                // Completion indicator
                _CompletionBadge(completed: todo.completed, color: accentColor),
                const SizedBox(width: 16),
                // Title and subtask info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        todo.title,
                        style: TextStyle(
                          color: isDark ? Colors.white : Colors.black87,
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
                Icon(
                  Icons.chevron_right,
                  color: isDark ? Colors.white38 : Colors.black26,
                ),
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
  final Color color;

  const _CompletionBadge({required this.completed, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: completed ? color : Colors.transparent,
        border: Border.all(
          color: completed ? color : Colors.grey,
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accentColor = Theme.of(context).colorScheme.primary;

    return Row(
      children: [
        if (query.isFetching && !query.hasData)
          SizedBox(
            width: 12,
            height: 12,
            child:
                CircularProgressIndicator(strokeWidth: 1, color: accentColor),
          )
        else
          Text(
            '$completedCount / $totalCount subtasks',
            style: TextStyle(
              color: isDark ? Colors.white54 : Colors.black45,
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
          SizedBox(
            width: 10,
            height: 10,
            child:
                CircularProgressIndicator(strokeWidth: 1, color: accentColor),
          ),
        ],
      ],
    );
  }
}
