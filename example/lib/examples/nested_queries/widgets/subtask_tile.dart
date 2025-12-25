import 'package:flutter/material.dart';
import '../../../api/api_client.dart';

/// A single subtask tile with toggle and delete actions
class SubtaskTile extends StatelessWidget {
  final Subtask subtask;
  final bool isToggling;
  final bool isDeleting;
  final VoidCallback onToggle;
  final VoidCallback onDelete;

  const SubtaskTile({
    super.key,
    required this.subtask,
    required this.isToggling,
    required this.isDeleting,
    required this.onToggle,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accentColor = Theme.of(context).colorScheme.primary;
    final isOptimistic = subtask.id < 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isOptimistic
            ? (isDark
                ? Color.lerp(const Color(0xFF2A2A3E), accentColor, 0.08)
                    ?.withAlpha(128)
                : Color.lerp(Colors.grey.shade100, accentColor, 0.05)
                    ?.withAlpha(128))
            : (isDark
                ? Color.lerp(const Color(0xFF2A2A3E), accentColor, 0.06)
                : Color.lerp(Colors.grey.shade100, accentColor, 0.03)),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isOptimistic
              ? accentColor.withAlpha(77)
              : accentColor.withAlpha(isDark ? 25 : 15),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          // Toggle button
          GestureDetector(
            onTap: isToggling || isOptimistic ? null : onToggle,
            child: isToggling
                ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: accentColor),
                  )
                : Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color:
                          subtask.completed ? accentColor : Colors.transparent,
                      border: Border.all(
                        color: subtask.completed
                            ? accentColor
                            : (isDark ? Colors.white38 : Colors.black26),
                        width: 2,
                      ),
                    ),
                    child: subtask.completed
                        ? const Icon(Icons.check, size: 12, color: Colors.white)
                        : null,
                  ),
          ),
          const SizedBox(width: 12),
          // Title
          Expanded(
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    subtask.title,
                    style: TextStyle(
                      color: isOptimistic
                          ? (isDark ? Colors.white70 : Colors.black54)
                          : (isDark ? Colors.white : Colors.black87),
                      decoration:
                          subtask.completed ? TextDecoration.lineThrough : null,
                      fontStyle:
                          isOptimistic ? FontStyle.italic : FontStyle.normal,
                    ),
                  ),
                ),
                if (isOptimistic)
                  Container(
                    margin: const EdgeInsets.only(left: 8),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: accentColor.withAlpha(51),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      'SAVING...',
                      style: TextStyle(
                        color: accentColor,
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          // Delete button
          IconButton(
            icon: isDeleting
                ? SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: accentColor),
                  )
                : Icon(
                    Icons.delete_outline,
                    size: 18,
                    color: isOptimistic
                        ? (isDark ? Colors.white24 : Colors.black12)
                        : (isDark ? Colors.white38 : Colors.black26),
                  ),
            onPressed: isDeleting || isOptimistic ? null : onDelete,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }
}
