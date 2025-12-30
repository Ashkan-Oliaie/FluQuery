import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:fluquery/fluquery.dart';

import '../models/models.dart';
import '../task_service.dart';

class TaskFilterBar extends StatelessWidget {
  const TaskFilterBar({super.key});

  @override
  Widget build(BuildContext context) {
    debugPrint('🔄 BUILD: TaskFilterBar');
    
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          _SearchField(),
          SizedBox(height: 12),
          Row(
            children: [
              _FilterChips(),
              Spacer(),
              _SortDropdown(),
            ],
          ),
          SizedBox(height: 12),
        ],
      ),
    );
  }
}

class _SearchField extends HookWidget {
  const _SearchField();

  @override
  Widget build(BuildContext context) {
    debugPrint('🔄 BUILD: _SearchField');
    
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final service = useService<TaskService>(key: kTaskService);
    final search = useSelect<TaskService, TaskState, String>(
      (s) => s.searchQuery,
      key: kTaskService,
    );

    return TextField(
      onChanged: (v) {
        debugPrint('⚡ ACTION: setSearchQuery("$v")');
        service.setSearchQuery(v);
      },
            decoration: InputDecoration(
              hintText: 'Search tasks...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: search.isNotEmpty
                  ? IconButton(
                onPressed: () {
                  debugPrint('⚡ ACTION: clearSearch');
                  service.setSearchQuery('');
                },
                icon: const Icon(Icons.clear),
              )
                  : null,
              filled: true,
              fillColor: isDark
                  ? Colors.white.withValues(alpha: 0.05)
                  : Colors.black.withValues(alpha: 0.03),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
            ),
          ),
    );
  }
}

class _FilterChips extends HookWidget {
  const _FilterChips();

  @override
  Widget build(BuildContext context) {
    debugPrint('🔄 BUILD: _FilterChips');
    
    final theme = Theme.of(context);
    final service = useService<TaskService>(key: kTaskService);
    final currentFilter = useSelect<TaskService, TaskState, TaskFilter>(
      (s) => s.filter,
      key: kTaskService,
    );

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: TaskFilter.values
          .map((f) => Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      label: Text(f.name.toUpperCase()),
                      selected: currentFilter == f,
                  onSelected: (_) {
                    debugPrint('⚡ ACTION: setFilter($f)');
                    service.setFilter(f);
                  },
                  selectedColor: theme.colorScheme.primary.withValues(alpha: 0.2),
                    ),
              ))
          .toList(),
    );
  }
}

class _SortDropdown extends HookWidget {
  const _SortDropdown();

  @override
  Widget build(BuildContext context) {
    debugPrint('🔄 BUILD: _SortDropdown');
    
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final service = useService<TaskService>(key: kTaskService);
    final currentSort = useSelect<TaskService, TaskState, TaskSort>(
      (s) => s.sort,
      key: kTaskService,
    );

    return PopupMenuButton<TaskSort>(
                initialValue: currentSort,
      onSelected: (s) {
        debugPrint('⚡ ACTION: setSort($s)');
        service.setSort(s);
      },
                itemBuilder: (_) => TaskSort.values
                    .map((s) => PopupMenuItem(value: s, child: Text(s.name)))
                    .toList(),
                child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.05)
                        : Colors.black.withValues(alpha: 0.03),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.sort, size: 16),
                      const SizedBox(width: 4),
                      Text(currentSort.name),
                      const Icon(Icons.arrow_drop_down, size: 16),
                    ],
                  ),
      ),
    );
  }
}
