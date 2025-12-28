import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:fluquery/fluquery.dart';

import '../task_viewmodel.dart';

class TaskHeader extends HookWidget {
  const TaskHeader({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Use selectors by type - no need to pass VM around
    final isLoading = useViewModelSelect<TaskViewModel, TaskState, bool>(
      context,
      (s) => s.isLoading,
    );
    final totalCount = useViewModelSelect<TaskViewModel, TaskState, int>(
      context,
      (s) => s.tasks.length,
    );
    final activeCount = useViewModelSelect<TaskViewModel, TaskState, int>(
      context,
      (s) => s.activeCount,
    );
    final completedCount = useViewModelSelect<TaskViewModel, TaskState, int>(
      context,
      (s) => s.completedCount,
    );

    // Get VM only for actions (refresh)
    final vm = useViewModel<TaskViewModel>(context);

    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: Icon(Icons.arrow_back,
                    color: isDark ? Colors.white70 : Colors.black54),
              ),
              const SizedBox(width: 8),
              Text('Task Manager',
                  style: theme.textTheme.headlineSmall
                      ?.copyWith(fontWeight: FontWeight.bold)),
              const Spacer(),
              if (isLoading)
                const Padding(
                  padding: EdgeInsets.only(right: 12),
                  child: SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              IconButton(
                  onPressed: vm.refresh, icon: const Icon(Icons.refresh)),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _Stat(
                  label: 'Total',
                  value: totalCount,
                  color: theme.colorScheme.primary),
              const SizedBox(width: 12),
              _Stat(label: 'Active', value: activeCount, color: Colors.orange),
              const SizedBox(width: 12),
              _Stat(label: 'Done', value: completedCount, color: Colors.green),
            ],
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String label;
  final int value;
  final Color color;

  const _Stat({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(value.toString(),
              style: TextStyle(
                  color: color, fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(width: 4),
          Text(label,
              style:
                  TextStyle(color: color.withValues(alpha: 0.8), fontSize: 12)),
        ],
      ),
    );
  }
}
