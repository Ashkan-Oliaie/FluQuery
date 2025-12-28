import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:fluquery/fluquery.dart';

import '../task_viewmodel.dart';

class TaskCard extends HookWidget {
  final Task task;
  final bool isSelected;

  const TaskCard({super.key, required this.task, required this.isSelected});

  @override
  Widget build(BuildContext context) {
    // Get VM for actions only
    final vm = useViewModel<TaskViewModel>(context);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final priorityColor = switch (task.priority) {
      TaskPriority.high => Colors.red,
      TaskPriority.medium => Colors.orange,
      TaskPriority.low => Colors.green,
    };

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: isDark
              ? Colors.white.withValues(alpha: isSelected ? 0.08 : 0.03)
              : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? theme.colorScheme.primary
                : (isDark
                    ? Colors.white.withValues(alpha: 0.1)
                    : Colors.black.withValues(alpha: 0.05)),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => vm.selectTask(isSelected ? null : task.id),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      // Checkbox
                      GestureDetector(
                        onTap: () => vm.toggleTask(task.id),
                        child: Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            color: task.completed
                                ? Colors.green
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                                color:
                                    task.completed ? Colors.green : Colors.grey,
                                width: 2),
                          ),
                          child: task.completed
                              ? const Icon(Icons.check,
                                  size: 16, color: Colors.white)
                              : null,
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Title
                      Expanded(
                        child: Text(
                          task.title,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            decoration: task.completed
                                ? TextDecoration.lineThrough
                                : null,
                            color: task.completed
                                ? theme.colorScheme.onSurface
                                    .withValues(alpha: 0.5)
                                : null,
                          ),
                        ),
                      ),
                      // Priority
                      Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                              color: priorityColor, shape: BoxShape.circle)),
                      const SizedBox(width: 8),
                      // Delete
                      IconButton(
                        onPressed: () => vm.deleteTask(task.id),
                        icon: const Icon(Icons.delete_outline, size: 20),
                        color: Colors.red.withValues(alpha: 0.7),
                        visualDensity: VisualDensity.compact,
                      ),
                    ],
                  ),
                  if (task.description != null && isSelected) ...[
                    const SizedBox(height: 8),
                    Text(task.description!,
                        style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurface
                                .withValues(alpha: 0.7))),
                  ],
                  if (isSelected) ...[
                    const SizedBox(height: 8),
                    Text(_formatDate(task.createdAt),
                        style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.onSurface
                                .withValues(alpha: 0.4))),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${date.day}/${date.month}/${date.year}';
  }
}
