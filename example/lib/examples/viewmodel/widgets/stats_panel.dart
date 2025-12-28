import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:fluquery/fluquery.dart';

import '../task_viewmodel.dart';

class StatsPanel extends HookWidget {
  const StatsPanel({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Get VM for accessing nested services
    final vm = useViewModel<TaskViewModel>(context);

    // Use selectors for TaskViewModel state
    final tasksCount = useViewModelSelect<TaskViewModel, TaskState, int>(
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
    final isLoading = useViewModelSelect<TaskViewModel, TaskState, bool>(
      context,
      (s) => s.isLoading,
    );

    // StatsService uses StatefulService - use selector
    final stats = useSelect<StatsService, StatsState, StatsState>((s) => s);

    // Other services still use ReactiveList
    final events = useValueListenable(vm.analytics.events);
    final undoStack = useValueListenable(vm.undo.undoStack);
    final redoStack = useValueListenable(vm.undo.redoStack);

    return Container(
      width: 280,
      decoration: BoxDecoration(
        color: isDark
            ? Colors.black.withValues(alpha: 0.3)
            : Colors.white.withValues(alpha: 0.9),
        border: Border(
          left: BorderSide(
            color: isDark
                ? Colors.white.withValues(alpha: 0.1)
                : Colors.black.withValues(alpha: 0.05),
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.1)
                      : Colors.black.withValues(alpha: 0.05),
                ),
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.analytics_rounded,
                    size: 20, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text('Services & State',
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold)),
              ],
            ),
          ),

          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Tasks state (from StatefulService)
                _ServiceCard(
                  icon: Icons.list_alt_rounded,
                  title: 'TaskState (StatefulService)',
                  color: Colors.teal,
                  children: [
                    _StatRow('Count', tasksCount.toString()),
                    _StatRow('Active', activeCount.toString()),
                    _StatRow('Completed', completedCount.toString()),
                    _StatRow('Is Loading', isLoading.toString()),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: vm.refresh,
                        icon: const Icon(Icons.refresh, size: 16),
                        label: const Text('Reload'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Stats Service (StatefulService)
                _ServiceCard(
                  icon: Icons.bar_chart_rounded,
                  title: 'StatsService (StatefulService)',
                  color: Colors.blue,
                  children: [
                    _StatRow('Tasks Created', stats.created.toString()),
                    _StatRow('Tasks Completed', stats.completed.toString()),
                    _StatRow('Tasks Deleted', stats.deleted.toString()),
                    _StatRow('Session', _formatDuration(vm.stats.session)),
                  ],
                ),
                const SizedBox(height: 16),

                // Undo Service (ReactiveList)
                _ServiceCard(
                  icon: Icons.undo_rounded,
                  title: 'UndoService (ReactiveList)',
                  color: Colors.orange,
                  children: [
                    _StatRow('Undo Stack', undoStack.length.toString()),
                    _StatRow('Redo Stack', redoStack.length.toString()),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: vm.undo.canUndo ? vm.undoLast : null,
                            icon: const Icon(Icons.undo, size: 16),
                            label: const Text('Undo'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: vm.undo.canRedo ? vm.redoLast : null,
                            icon: const Icon(Icons.redo, size: 16),
                            label: const Text('Redo'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Analytics Service (ReactiveList)
                _ServiceCard(
                  icon: Icons.timeline_rounded,
                  title: 'AnalyticsService (ReactiveList)',
                  color: Colors.purple,
                  children: [
                    _StatRow('Total Events', events.length.toString()),
                    const SizedBox(height: 8),
                    Text('Recent:',
                        style: theme.textTheme.labelSmall
                            ?.copyWith(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    ...events.reversed.take(5).map((e) => Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Row(
                            children: [
                              Container(
                                width: 6,
                                height: 6,
                                decoration: BoxDecoration(
                                    color: _eventColor(e.type),
                                    shape: BoxShape.circle),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(e.type,
                                    style: theme.textTheme.labelSmall
                                        ?.copyWith(fontFamily: 'monospace'),
                                    overflow: TextOverflow.ellipsis),
                              ),
                              Text(_formatTime(e.timestamp),
                                  style: theme.textTheme.labelSmall?.copyWith(
                                      color: theme.colorScheme.onSurface
                                          .withValues(alpha: 0.4))),
                            ],
                          ),
                        )),
                    if (events.isEmpty)
                      Text('No events yet',
                          style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.onSurface
                                  .withValues(alpha: 0.4),
                              fontStyle: FontStyle.italic)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatDuration(Duration d) {
    if (d.inMinutes < 1) return '${d.inSeconds}s';
    if (d.inHours < 1) return '${d.inMinutes}m ${d.inSeconds % 60}s';
    return '${d.inHours}h ${d.inMinutes % 60}m';
  }

  String _formatTime(DateTime t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}:${t.second.toString().padLeft(2, '0')}';

  Color _eventColor(String type) {
    if (type.contains('created')) return Colors.green;
    if (type.contains('completed')) return Colors.blue;
    if (type.contains('deleted') || type.contains('cleared')) return Colors.red;
    if (type.contains('undo')) return Colors.orange;
    if (type.contains('redo')) return Colors.purple;
    return Colors.grey;
  }
}

class _ServiceCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final Color color;
  final List<Widget> children;

  const _ServiceCard(
      {required this.icon,
      required this.title,
      required this.color,
      required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 8),
              Expanded(
                child: Text(title,
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: color,
                        fontFamily: 'monospace'),
                    overflow: TextOverflow.ellipsis),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  final String label;
  final String value;

  const _StatRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: theme.textTheme.labelSmall),
          Text(value,
              style: theme.textTheme.labelSmall
                  ?.copyWith(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
