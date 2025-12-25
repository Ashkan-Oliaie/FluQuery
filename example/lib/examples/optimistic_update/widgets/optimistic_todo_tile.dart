import 'package:flutter/material.dart';
import '../../../api/api_client.dart';

/// Todo tile with optimistic update animation
class OptimisticTodoTile extends StatelessWidget {
  final Todo todo;
  final bool isUpdating;
  final VoidCallback onToggle;

  const OptimisticTodoTile({
    super.key,
    required this.todo,
    required this.isUpdating,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accentColor = Theme.of(context).colorScheme.primary;

    return GestureDetector(
      onTap: onToggle,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: todo.completed
              ? accentColor.withAlpha(26)
              : (isDark
                  ? Color.lerp(const Color(0xFF1A1A2E), accentColor, 0.04)
                  : Color.lerp(Colors.white, accentColor, 0.02)),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: todo.completed
                ? accentColor.withAlpha(77)
                : accentColor.withAlpha(isDark ? 30 : 18),
          ),
        ),
        child: Row(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: todo.completed ? accentColor : Colors.transparent,
                border: Border.all(
                  color: todo.completed
                      ? accentColor
                      : (isDark ? Colors.white30 : Colors.black26),
                  width: 2,
                ),
              ),
              child: todo.completed
                  ? const Icon(Icons.check, size: 16, color: Colors.white)
                  : null,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                todo.title,
                style: TextStyle(
                  fontSize: 16,
                  color: todo.completed
                      ? (isDark ? Colors.white54 : Colors.black38)
                      : (isDark ? Colors.white : Colors.black87),
                  decoration:
                      todo.completed ? TextDecoration.lineThrough : null,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: accentColor.withAlpha(isDark ? 20 : 15),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                '#${todo.id}',
                style: TextStyle(
                  fontSize: 12,
                  color: accentColor.withAlpha(180),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
