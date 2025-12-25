import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:fluquery/fluquery.dart';
import '../../../api/api_client.dart';
import '../hooks/use_todo_mutations.dart';
import 'subtask_tile.dart';
import 'activity_tile.dart';

/// Modal showing todo details with multiple queries and optimistic updates
/// 
/// Key FluQuery features demonstrated:
/// 1. Multiple queries in one widget (details + activities)
/// 2. Optimistic updates (no refetch on mutation!)
/// 3. Auto-polling for activities
/// 4. Cache invalidation strategies
class TodoDetailsModal extends HookWidget {
  final int todoId;
  final ScrollController scrollController;

  const TodoDetailsModal({
    super.key,
    required this.todoId,
    required this.scrollController,
  });

  @override
  Widget build(BuildContext context) {
    final client = useQueryClient();
    final newSubtaskController = useTextEditingController();

    // Query for full todo details
    final detailsQuery = useQuery<TodoDetails, Object>(
      queryKey: ['todo-details', todoId],
      queryFn: (_) => ApiClient.getTodoDetails(todoId),
      staleTime: const StaleTime(Duration(minutes: 1)),
    );

    // Separate query for activities (auto-refreshes in background)
    final activitiesQuery = useQuery<List<Activity>, Object>(
      queryKey: ['todo-activities', todoId],
      queryFn: (_) => ApiClient.getTodoActivities(todoId),
      staleTime: const StaleTime(Duration(seconds: 30)),
      refetchInterval: const Duration(seconds: 30),
    );

    // All mutations with proper optimistic updates
    final mutations = useTodoMutations(todoId: todoId, context: context);

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF1A1A2E),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Handle
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // Content
          Expanded(
            child: detailsQuery.isLoading && !detailsQuery.hasData
                ? const Center(child: CircularProgressIndicator())
                : detailsQuery.isError
                    ? _ErrorView(
                        error: detailsQuery.error.toString(),
                        onRetry: () => detailsQuery.refetch(),
                      )
                    : _DetailsContent(
                        details: detailsQuery.data!,
                        activitiesQuery: activitiesQuery,
                        mutations: mutations,
                        subtaskController: newSubtaskController,
                        scrollController: scrollController,
                        client: client,
                        todoId: todoId,
                      ),
          ),
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String error;
  final VoidCallback onRetry;

  const _ErrorView({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, size: 48, color: Colors.red),
          const SizedBox(height: 16),
          Text('Error: $error', style: const TextStyle(color: Colors.white)),
          const SizedBox(height: 16),
          ElevatedButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}

class _DetailsContent extends StatelessWidget {
  final TodoDetails details;
  final QueryResult<List<Activity>, Object> activitiesQuery;
  final TodoMutations mutations;
  final TextEditingController subtaskController;
  final ScrollController scrollController;
  final QueryClient client;
  final int todoId;

  const _DetailsContent({
    required this.details,
    required this.activitiesQuery,
    required this.mutations,
    required this.subtaskController,
    required this.scrollController,
    required this.client,
    required this.todoId,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      controller: scrollController,
      padding: const EdgeInsets.all(20),
      children: [
        // Header
        _Header(
          title: details.title,
          onRefresh: () => client.invalidateQueries(
            queryKey: ['todo-details', todoId],
            refetchType: true,
          ),
        ),
        const SizedBox(height: 16),

        // Progress bar
        _ProgressBar(
          completedHours: details.completedHours,
          estimatedHours: details.estimatedHours,
        ),
        const SizedBox(height: 20),

        // Meta info row
        _MetaRow(
          details: details,
          onPriorityTap: () => _showPriorityPicker(context),
        ),
        const SizedBox(height: 8),

        // Tags
        if (details.tags.isNotEmpty) ...[
          Wrap(
            spacing: 8,
            children: details.tags.map((tag) => Chip(
              label: Text(tag, style: const TextStyle(fontSize: 12)),
              backgroundColor: const Color(0xFF2A2A3E),
              side: BorderSide.none,
            )).toList(),
          ),
          const SizedBox(height: 24),
        ],

        // Subtasks section
        _SectionHeader(
          title: 'Subtasks',
          trailing: Text(
            '${details.subtasks.where((s) => s.completed).length}/${details.subtasks.length}',
            style: const TextStyle(color: Colors.white70),
          ),
        ),
        const SizedBox(height: 12),

        // Add subtask input
        _AddSubtaskInput(
          controller: subtaskController,
          isLoading: mutations.create.isPending,
          onSubmit: (title) {
            if (title.trim().isNotEmpty) {
              mutations.create.mutate(title.trim());
              subtaskController.clear();
            }
          },
        ),
        const SizedBox(height: 12),

        // Subtasks list - cache updated on success, no refetch!
        ...details.subtasks.map((subtask) => SubtaskTile(
          subtask: subtask,
          isToggling: mutations.toggle.isPending &&
              mutations.toggle.variables?.subtaskId == subtask.id,
          isDeleting: mutations.delete.isPending &&
              mutations.delete.variables == subtask.id,
          onToggle: () => mutations.toggle.mutate((
            subtaskId: subtask.id,
            completed: !subtask.completed,
          )),
          onDelete: () => mutations.delete.mutate(subtask.id),
        )),

        const SizedBox(height: 24),

        // Activity section
        _SectionHeader(
          title: 'Activity',
          trailing: activitiesQuery.isFetching
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (activitiesQuery.isStale)
                      Container(
                        margin: const EdgeInsets.only(right: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF59E0B).withAlpha(51),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'STALE',
                          style: TextStyle(
                            color: Color(0xFFF59E0B),
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    IconButton(
                      icon: const Icon(Icons.refresh, size: 18, color: Colors.white70),
                      onPressed: () => activitiesQuery.refetch(),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
        ),
        const SizedBox(height: 8),
        Text(
          'Auto-refreshes every 30s',
          style: TextStyle(color: Colors.white.withAlpha(77), fontSize: 11),
        ),
        const SizedBox(height: 12),

        // Activities list
        if (activitiesQuery.isLoading && !activitiesQuery.hasData)
          const Center(child: CircularProgressIndicator())
        else if (activitiesQuery.hasData)
          ...activitiesQuery.data!.take(10).map((activity) => ActivityTile(activity: activity))
        else
          const Text('No activities', style: TextStyle(color: Colors.white54)),

        const SizedBox(height: 40),
      ],
    );
  }

  void _showPriorityPicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF2A2A3E),
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: ['low', 'medium', 'high', 'urgent'].map((priority) {
          final isSelected = priority == details.priority;
          return ListTile(
            leading: Icon(Icons.flag, color: _priorityColor(priority)),
            title: Text(
              priority.toUpperCase(),
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.white70,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
            trailing: isSelected ? const Icon(Icons.check, color: Colors.white) : null,
            onTap: () {
              mutations.priority.mutate(priority);
              Navigator.pop(context);
            },
          );
        }).toList(),
      ),
    );
  }

  Color _priorityColor(String priority) {
    switch (priority) {
      case 'urgent':
        return const Color(0xFFEF4444);
      case 'high':
        return const Color(0xFFF59E0B);
      case 'medium':
        return const Color(0xFF6366F1);
      case 'low':
        return const Color(0xFF10B981);
      default:
        return Colors.grey;
    }
  }
}

class _Header extends StatelessWidget {
  final String title;
  final VoidCallback onRefresh;

  const _Header({required this.title, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.refresh, color: Colors.white70),
          onPressed: onRefresh,
          tooltip: 'Force refetch (normally not needed!)',
        ),
      ],
    );
  }
}

class _ProgressBar extends StatelessWidget {
  final int completedHours;
  final int estimatedHours;

  const _ProgressBar({required this.completedHours, required this.estimatedHours});

  @override
  Widget build(BuildContext context) {
    final progress = estimatedHours > 0 ? completedHours / estimatedHours : 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Progress',
              style: TextStyle(color: Colors.white.withAlpha(179), fontSize: 12),
            ),
            Text(
              '$completedHours / $estimatedHours hours',
              style: TextStyle(color: Colors.white.withAlpha(179), fontSize: 12),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: progress.clamp(0.0, 1.0),
            backgroundColor: Colors.white.withAlpha(26),
            valueColor: AlwaysStoppedAnimation(
              progress >= 1.0 ? const Color(0xFF10B981) : const Color(0xFF6366F1),
            ),
            minHeight: 8,
          ),
        ),
      ],
    );
  }
}

class _MetaRow extends StatelessWidget {
  final TodoDetails details;
  final VoidCallback onPriorityTap;

  const _MetaRow({required this.details, required this.onPriorityTap});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        _MetaChip(
          icon: Icons.flag,
          label: details.priority.toUpperCase(),
          color: _priorityColor(details.priority),
          onTap: onPriorityTap,
        ),
        if (details.assignee != null)
          _MetaChip(
            icon: Icons.person,
            label: details.assignee!.name,
            color: const Color(0xFF6366F1),
          ),
        if (details.dueDate != null)
          _MetaChip(
            icon: Icons.calendar_today,
            label: _formatDate(details.dueDate!),
            color: const Color(0xFFF59E0B),
          ),
      ],
    );
  }

  Color _priorityColor(String priority) {
    switch (priority) {
      case 'urgent':
        return const Color(0xFFEF4444);
      case 'high':
        return const Color(0xFFF59E0B);
      case 'medium':
        return const Color(0xFF6366F1);
      case 'low':
        return const Color(0xFF10B981);
      default:
        return Colors.grey;
    }
  }

  String _formatDate(DateTime date) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[date.month - 1]} ${date.day}';
  }
}

class _MetaChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onTap;

  const _MetaChip({
    required this.icon,
    required this.label,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: color.withAlpha(26),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w500),
            ),
            if (onTap != null) ...[
              const SizedBox(width: 4),
              Icon(Icons.keyboard_arrow_down, size: 14, color: color),
            ],
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final Widget? trailing;

  const _SectionHeader({required this.title, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        if (trailing != null) trailing!,
      ],
    );
  }
}

class _AddSubtaskInput extends StatelessWidget {
  final TextEditingController controller;
  final bool isLoading;
  final void Function(String) onSubmit;

  const _AddSubtaskInput({
    required this.controller,
    required this.isLoading,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: controller,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Add new subtask...',
              hintStyle: TextStyle(color: Colors.white.withAlpha(77)),
              filled: true,
              fillColor: const Color(0xFF2A2A3E),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
            onSubmitted: onSubmit,
          ),
        ),
        const SizedBox(width: 12),
        IconButton(
          icon: isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.add_circle, color: Color(0xFF6366F1)),
          onPressed: () => onSubmit(controller.text),
        ),
      ],
    );
  }
}

