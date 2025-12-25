import 'package:flutter/material.dart';
import '../../../api/api_client.dart';

/// A reusable todo tile component
class TodoTile extends StatelessWidget {
  final Todo todo;
  final VoidCallback? onToggle;
  final VoidCallback? onDelete;
  final bool isToggling;
  final bool isDeleting;
  final bool showActions;

  const TodoTile({
    super.key,
    required this.todo,
    this.onToggle,
    this.onDelete,
    this.isToggling = false,
    this.isDeleting = false,
    this.showActions = true,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accentColor = Theme.of(context).colorScheme.primary;

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 200),
      opacity: isDeleting ? 0.5 : 1.0,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark
              ? Color.lerp(const Color(0xFF1A1A2E), accentColor, 0.04)
              : Color.lerp(Colors.white, accentColor, 0.02),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: accentColor.withAlpha(isDark ? 30 : 18)),
        ),
        child: Row(
          children: [
            GestureDetector(
              onTap: isToggling || onToggle == null ? null : onToggle,
              child: Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: todo.completed
                      ? accentColor.withAlpha(51)
                      : (isDark
                          ? Colors.white.withAlpha(26)
                          : Colors.black.withAlpha(13)),
                  border: Border.all(
                    color: todo.completed
                        ? accentColor
                        : (isDark ? Colors.white30 : Colors.black26),
                    width: 2,
                  ),
                ),
                child: isToggling
                    ? Padding(
                        padding: const EdgeInsets.all(4),
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: accentColor,
                        ),
                      )
                    : todo.completed
                        ? Icon(Icons.check, size: 16, color: accentColor)
                        : null,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    todo.title,
                    style: TextStyle(
                      color: todo.completed
                          ? (isDark ? Colors.white54 : Colors.black38)
                          : (isDark ? Colors.white : Colors.black87),
                      decoration:
                          todo.completed ? TextDecoration.lineThrough : null,
                    ),
                  ),
                  Text(
                    '#${todo.id}',
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark ? Colors.white30 : Colors.black26,
                    ),
                  ),
                ],
              ),
            ),
            if (showActions && onDelete != null)
              IconButton(
                icon: isDeleting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.red,
                        ),
                      )
                    : Icon(Icons.delete_outline,
                        color: Colors.red.withAlpha(179)),
                onPressed: isDeleting ? null : onDelete,
              ),
          ],
        ),
      ),
    );
  }
}

/// A simpler read-only todo tile
class SimpleTodoTile extends StatelessWidget {
  final Todo todo;

  const SimpleTodoTile({super.key, required this.todo});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accentColor = Theme.of(context).colorScheme.primary;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark
            ? Color.lerp(const Color(0xFF1A1A2E), accentColor, 0.04)
            : Color.lerp(Colors.white, accentColor, 0.02),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: accentColor.withAlpha(isDark ? 30 : 18)),
      ),
      child: Row(
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: todo.completed
                  ? accentColor.withAlpha(51)
                  : (isDark
                      ? Colors.white.withAlpha(26)
                      : Colors.black.withAlpha(13)),
              border: Border.all(
                color: todo.completed
                    ? accentColor
                    : (isDark ? Colors.white30 : Colors.black26),
                width: 2,
              ),
            ),
            child: todo.completed
                ? Icon(Icons.check, size: 14, color: accentColor)
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              todo.title,
              style: TextStyle(
                color: todo.completed
                    ? (isDark ? Colors.white54 : Colors.black38)
                    : (isDark ? Colors.white : Colors.black87),
                decoration: todo.completed ? TextDecoration.lineThrough : null,
              ),
            ),
          ),
          Text(
            '#${todo.id}',
            style: TextStyle(
              fontSize: 12,
              color: isDark ? Colors.white30 : Colors.black26,
            ),
          ),
        ],
      ),
    );
  }
}
