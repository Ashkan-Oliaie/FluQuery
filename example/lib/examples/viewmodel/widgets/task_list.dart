import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:fluquery/fluquery.dart';

import '../task_viewmodel.dart';
import 'task_card.dart';

class TaskList extends HookWidget {
  const TaskList({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Use selectors by type - only rebuilds when selected value changes
    final isLoading = useViewModelSelect<TaskViewModel, TaskState, bool>(
      context,
      (s) => s.isLoading,
    );
    final tasks = useViewModelSelect<TaskViewModel, TaskState, List<Task>>(
      context,
      (s) => s.filteredTasks,
    );
    final selectedId = useViewModelSelect<TaskViewModel, TaskState, String?>(
      context,
      (s) => s.selectedTaskId,
    );

    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (tasks.isEmpty) {
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
      itemCount: tasks.length,
      itemBuilder: (_, i) =>
          TaskCard(task: tasks[i], isSelected: selectedId == tasks[i].id),
    );
  }
}
