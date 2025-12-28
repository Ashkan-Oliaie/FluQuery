import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:fluquery/fluquery.dart';

import '../task_viewmodel.dart';

class AddTaskFab extends HookWidget {
  const AddTaskFab({super.key});

  @override
  Widget build(BuildContext context) {
    // Use selector by type - only rebuilds when completedCount changes
    final completedCount = useViewModelSelect<TaskViewModel, TaskState, int>(
      context,
      (s) => s.completedCount,
    );

    // Get VM for actions
    final vm = useViewModel<TaskViewModel>(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        if (completedCount > 0)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: FloatingActionButton.small(
              heroTag: 'clear',
              onPressed: vm.clearCompleted,
              backgroundColor: Colors.red.shade400,
              child: const Icon(Icons.delete_sweep),
            ),
          ),
        FloatingActionButton.extended(
          heroTag: 'add',
          onPressed: () => _showAddDialog(context, vm),
          icon: const Icon(Icons.add),
          label: const Text('Add Task'),
        ),
      ],
    );
  }

  void _showAddDialog(BuildContext context, TaskViewModel vm) {
    final titleCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    var priority = TaskPriority.medium;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final theme = Theme.of(ctx);
        final isDark = theme.brightness == Brightness.dark;

        return StatefulBuilder(
          builder: (ctx, setState) => Container(
            padding:
                EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1A1A2E) : Colors.white,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('New Task',
                      style: theme.textTheme.titleLarge
                          ?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 20),
                  TextField(
                      controller: titleCtrl,
                      autofocus: true,
                      decoration: const InputDecoration(
                          labelText: 'Title', border: OutlineInputBorder())),
                  const SizedBox(height: 16),
                  TextField(
                      controller: descCtrl,
                      decoration: const InputDecoration(
                          labelText: 'Description (optional)',
                          border: OutlineInputBorder()),
                      maxLines: 2),
                  const SizedBox(height: 16),
                  Text('Priority',
                      style: theme.textTheme.labelLarge
                          ?.copyWith(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  SegmentedButton<TaskPriority>(
                    segments: const [
                      ButtonSegment(
                          value: TaskPriority.low, label: Text('Low')),
                      ButtonSegment(
                          value: TaskPriority.medium, label: Text('Medium')),
                      ButtonSegment(
                          value: TaskPriority.high, label: Text('High')),
                    ],
                    selected: {priority},
                    onSelectionChanged: (s) =>
                        setState(() => priority = s.first),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                          child: OutlinedButton(
                              onPressed: () => Navigator.pop(ctx),
                              child: const Text('Cancel'))),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton(
                          onPressed: () {
                            if (titleCtrl.text.isNotEmpty) {
                              vm.addTask(
                                  titleCtrl.text,
                                  descCtrl.text.isEmpty ? null : descCtrl.text,
                                  priority);
                              Navigator.pop(ctx);
                            }
                          },
                          child: const Text('Add'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
