import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:fluquery/fluquery.dart';

import '../task_service.dart';

class TaskHeader extends StatelessWidget {
  const TaskHeader({super.key});

  @override
  Widget build(BuildContext context) {
    debugPrint('🔄 BUILD: TaskHeader');

    return Container(
      padding: const EdgeInsets.all(20),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _TitleBar(),
          SizedBox(height: 16),
          _StatsRow(),
        ],
      ),
    );
  }
}

class _TitleBar extends HookWidget {
  const _TitleBar();

  @override
  Widget build(BuildContext context) {
    debugPrint('🔄 BUILD: _TitleBar');
    
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final service = useService<TaskService>(key: kTaskService);
    final isLoading = useSelect<TaskService, TaskState, bool>(
      (s) => s.isLoading,
      key: kTaskService,
    );

    return Row(
            children: [
              IconButton(
                onPressed: () => Navigator.pop(context),
          icon: Icon(
            Icons.arrow_back,
            color: isDark ? Colors.white70 : Colors.black54,
          ),
              ),
              const SizedBox(width: 8),
        Text(
          'Task Manager',
          style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
        ),
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
          onPressed: () {
            debugPrint('⚡ ACTION: refresh');
            service.refresh();
          },
          icon: const Icon(Icons.refresh),
        ),
            ],
    );
  }
}

class _StatsRow extends HookWidget {
  const _StatsRow();

  @override
  Widget build(BuildContext context) {
    debugPrint('🔄 BUILD: _StatsRow');
    
    final theme = Theme.of(context);

    final totalCount = useSelect<TaskService, TaskState, int>(
      (s) => s.tasks.length,
      key: kTaskService,
    );
    final activeCount = useSelect<TaskService, TaskState, int>(
      (s) => s.activeCount,
      key: kTaskService,
    );
    final completedCount = useSelect<TaskService, TaskState, int>(
      (s) => s.completedCount,
      key: kTaskService,
    );

    return Row(
            children: [
        _StatBadge(label: 'Total', value: totalCount, color: theme.colorScheme.primary),
              const SizedBox(width: 12),
        _StatBadge(label: 'Active', value: activeCount, color: Colors.orange),
              const SizedBox(width: 12),
        _StatBadge(label: 'Done', value: completedCount, color: Colors.green),
        ],
    );
  }
}

class _StatBadge extends StatelessWidget {
  final String label;
  final int value;
  final Color color;

  const _StatBadge({
    required this.label,
    required this.value,
    required this.color,
  });

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
          Text(
            value.toString(),
            style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(color: color.withValues(alpha: 0.8), fontSize: 12),
          ),
        ],
      ),
    );
  }
}
