import 'package:flutter/material.dart';
import '../../../api/api_client.dart';
import '../../shared/shared.dart';

class RaceTodoList extends StatelessWidget {
  final List<Todo> todos;
  final bool isFetching;

  const RaceTodoList({
    super.key,
    required this.todos,
    this.isFetching = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accentColor = Theme.of(context).colorScheme.primary;

    if (todos.isEmpty) {
      return const EmptyState(icon: Icons.inbox, text: 'No todos');
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              '${todos.length} items',
              style: TextStyle(
                color: isDark ? Colors.white54 : Colors.black45,
                fontSize: 12,
              ),
            ),
            if (isFetching) ...[
              const SizedBox(width: 8),
              SmallSpinner(color: accentColor, size: 12),
            ],
          ],
        ),
        const SizedBox(height: 8),
        ...todos.take(5).map((todo) => _TodoItem(todo: todo)),
        if (todos.length > 5)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              '+ ${todos.length - 5} more...',
              style: TextStyle(
                color: isDark ? Colors.white38 : Colors.black26,
                fontSize: 11,
              ),
            ),
          ),
      ],
    );
  }
}

class _TodoItem extends StatelessWidget {
  final Todo todo;

  const _TodoItem({required this.todo});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accentColor = Theme.of(context).colorScheme.primary;

    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: isDark
            ? Color.lerp(const Color(0xFF1A1A2E), accentColor, 0.04)
            : Color.lerp(Colors.white, accentColor, 0.02),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: accentColor.withAlpha(isDark ? 25 : 15)),
      ),
      child: Row(
        children: [
          Icon(
            todo.completed ? Icons.check_circle : Icons.radio_button_unchecked,
            color: todo.completed
                ? accentColor
                : (isDark ? Colors.white38 : Colors.black26),
            size: 16,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              todo.title,
              style: TextStyle(
                color: todo.completed
                    ? (isDark ? Colors.white54 : Colors.black38)
                    : (isDark ? Colors.white : Colors.black87),
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
  }
}
