import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:fluquery/fluquery.dart';

import '../models/models.dart';
import '../task_service.dart';
import 'task_card.dart';

/// TaskList - only rebuilds when:
/// - isLoading changes
/// - Task IDs change (add/remove/reorder)
///
/// Does NOT rebuild when individual task properties change.
class TaskList extends HookWidget {
  const TaskList({super.key});

  @override
  Widget build(BuildContext context) {
    debugPrint('🔄 BUILD: TaskList');

    final theme = Theme.of(context);

    final isLoading = useSelect<TaskService, TaskState, bool>(
      (s) => s.isLoading,
      key: kTaskService,
    );

    // Only get the IDs - rebuilds only when tasks added/removed/reordered
    final taskIds = useSelectIds<TaskService, TaskState, Task, String>(
      (s) => s.filteredTasks,
      (task) => task.id,
      key: kTaskService,
    );

    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (taskIds.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inbox_rounded,
                size: 64,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.2)),
            const SizedBox(height: 16),
            Text('No tasks found',
                style: theme.textTheme.titleMedium?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.5))),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      itemCount: taskIds.length,
      // Each TaskCard handles its own state subscription
      itemBuilder: (_, i) => TaskCard(taskId: taskIds[i]),
    );
  }
}
