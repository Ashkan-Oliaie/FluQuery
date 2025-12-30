import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:fluquery/fluquery.dart';

import '../models/models.dart';
import '../task_service.dart';

class StatsPanel extends StatelessWidget {
  const StatsPanel({super.key});

  @override
  Widget build(BuildContext context) {
    debugPrint('🔄 BUILD: StatsPanel');
    
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

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
                Icon(Icons.analytics_rounded, size: 20, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  'Services & State',
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          const Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(16),
              child: Column(
              children: [
                  _TaskStateCard(),
                  SizedBox(height: 16),
                  _StatsServiceCard(),
                  SizedBox(height: 16),
                  _UndoServiceCard(),
                  SizedBox(height: 16),
                  _AnalyticsServiceCard(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TaskStateCard extends HookWidget {
  const _TaskStateCard();

  @override
  Widget build(BuildContext context) {
    debugPrint('🔄 BUILD: _TaskStateCard');
    
    final taskService = useService<TaskService>(key: kTaskService);
    final tasksCount = useSelect<TaskService, TaskState, int>((s) => s.tasks.length, key: kTaskService);
    final activeCount = useSelect<TaskService, TaskState, int>((s) => s.activeCount, key: kTaskService);
    final completedCount = useSelect<TaskService, TaskState, int>((s) => s.completedCount, key: kTaskService);
    final isLoading = useSelect<TaskService, TaskState, bool>((s) => s.isLoading, key: kTaskService);

    return _ServiceCard(
                  icon: Icons.list_alt_rounded,
                  title: 'TaskState',
                  color: Colors.teal,
                  children: [
                    _StatRow('Count', tasksCount.toString()),
                    _StatRow('Active', activeCount.toString()),
                    _StatRow('Completed', completedCount.toString()),
                    _StatRow('Loading', isLoading.toString()),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
            onPressed: () {
              debugPrint('⚡ ACTION: refresh (from StatsPanel)');
              taskService.refresh();
            },
                        icon: const Icon(Icons.refresh, size: 16),
                        label: const Text('Reload'),
                      ),
                    ),
                  ],
    );
  }
}

class _StatsServiceCard extends HookWidget {
  const _StatsServiceCard();

  @override
  Widget build(BuildContext context) {
    debugPrint('🔄 BUILD: _StatsServiceCard');
    
    final statsService = useService<StatsService>(key: kStats);
    final stats = useSelect<StatsService, StatsState, StatsState>((s) => s, key: kStats);

    return _ServiceCard(
                  icon: Icons.bar_chart_rounded,
                  title: 'StatsService',
                  color: Colors.blue,
                  children: [
                    _StatRow('Created', stats.created.toString()),
                    _StatRow('Completed', stats.completed.toString()),
                    _StatRow('Deleted', stats.deleted.toString()),
                    _StatRow('Session', _formatDuration(statsService.session)),
                  ],
    );
  }

  String _formatDuration(Duration d) {
    if (d.inMinutes < 1) return '${d.inSeconds}s';
    if (d.inHours < 1) return '${d.inMinutes}m ${d.inSeconds % 60}s';
    return '${d.inHours}h ${d.inMinutes % 60}m';
  }
}

class _UndoServiceCard extends HookWidget {
  const _UndoServiceCard();

  @override
  Widget build(BuildContext context) {
    debugPrint('🔄 BUILD: _UndoServiceCard');
    
    final taskService = useService<TaskService>(key: kTaskService);
    final undoService = useService<UndoService>(key: kUndo);
    final undoStack = useValueListenable(undoService.undoStack);
    final redoStack = useValueListenable(undoService.redoStack);

    return _ServiceCard(
                  icon: Icons.undo_rounded,
                  title: 'UndoService',
                  color: Colors.orange,
                  children: [
                    _StatRow('Undo Stack', undoStack.length.toString()),
                    _StatRow('Redo Stack', redoStack.length.toString()),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                onPressed: undoService.canUndo ? () {
                  debugPrint('⚡ ACTION: undoLast');
                  taskService.undoLast();
                } : null,
                            icon: const Icon(Icons.undo, size: 16),
                            label: const Text('Undo'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                onPressed: undoService.canRedo ? () {
                  debugPrint('⚡ ACTION: redoLast');
                  taskService.redoLast();
                } : null,
                            icon: const Icon(Icons.redo, size: 16),
                            label: const Text('Redo'),
                          ),
                        ),
                      ],
                    ),
                  ],
    );
  }
}

class _AnalyticsServiceCard extends HookWidget {
  const _AnalyticsServiceCard();

  @override
  Widget build(BuildContext context) {
    debugPrint('🔄 BUILD: _AnalyticsServiceCard');
    
    final theme = Theme.of(context);
    final analyticsService = useService<AnalyticsService>(key: kAnalytics);
    final events = useValueListenable(analyticsService.events);

    return _ServiceCard(
                  icon: Icons.timeline_rounded,
                  title: 'AnalyticsService',
                  color: Colors.purple,
                  children: [
                    _StatRow('Total Events', events.length.toString()),
                    const SizedBox(height: 8),
        Text('Recent:', style: theme.textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
        ...events.reversed.take(5).map((e) => _EventRow(event: e)),
        if (events.isEmpty)
          Text(
            'No events yet',
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
              fontStyle: FontStyle.italic,
            ),
          ),
      ],
    );
  }
}

class _EventRow extends StatelessWidget {
  final TaskEvent event;

  const _EventRow({required this.event});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Row(
                            children: [
                              Container(
                                width: 6,
                                height: 6,
            decoration: BoxDecoration(color: _eventColor(event.type), shape: BoxShape.circle),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
            child: Text(
              event.type,
              style: theme.textTheme.labelSmall?.copyWith(fontFamily: 'monospace'),
              overflow: TextOverflow.ellipsis,
            ),
                              ),
          Text(
            _formatTime(event.timestamp),
                          style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
            ),
          ),
        ],
      ),
    );
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

  const _ServiceCard({
    required this.icon,
    required this.title,
    required this.color,
    required this.children,
  });

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
              Text(title, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color)),
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
          Text(value, style: theme.textTheme.labelSmall?.copyWith(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
