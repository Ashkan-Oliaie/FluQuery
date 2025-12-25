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
    // Show if this is an optimistic (temporary) subtask
    final isOptimistic = subtask.id < 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isOptimistic 
            ? const Color(0xFF2A2A3E).withAlpha(128) 
            : const Color(0xFF2A2A3E),
        borderRadius: BorderRadius.circular(8),
        border: isOptimistic
            ? Border.all(color: const Color(0xFF6366F1).withAlpha(77), width: 1)
            : null,
      ),
      child: Row(
        children: [
          // Toggle button
          GestureDetector(
            onTap: isToggling || isOptimistic ? null : onToggle,
            child: isToggling
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: subtask.completed
                          ? const Color(0xFF10B981)
                          : Colors.transparent,
                      border: Border.all(
                        color: subtask.completed
                            ? const Color(0xFF10B981)
                            : Colors.white38,
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
                      color: isOptimistic ? Colors.white70 : Colors.white,
                      decoration: subtask.completed ? TextDecoration.lineThrough : null,
                      fontStyle: isOptimistic ? FontStyle.italic : FontStyle.normal,
                    ),
                  ),
                ),
                if (isOptimistic)
                  Container(
                    margin: const EdgeInsets.only(left: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFF6366F1).withAlpha(51),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      'SAVING...',
                      style: TextStyle(
                        color: Color(0xFF6366F1),
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
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(
                    Icons.delete_outline, 
                    size: 18, 
                    color: isOptimistic ? Colors.white24 : Colors.white38,
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


