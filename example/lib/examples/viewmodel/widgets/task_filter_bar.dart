import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:fluquery/fluquery.dart';

import '../task_viewmodel.dart';

class TaskFilterBar extends HookWidget {
  const TaskFilterBar({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Use selectors by type
    final currentFilter =
        useViewModelSelect<TaskViewModel, TaskState, TaskFilter>(
      context,
      (s) => s.filter,
    );
    final currentSort = useViewModelSelect<TaskViewModel, TaskState, TaskSort>(
      context,
      (s) => s.sort,
    );
    final search = useViewModelSelect<TaskViewModel, TaskState, String>(
      context,
      (s) => s.searchQuery,
    );

    // Get VM for actions
    final vm = useViewModel<TaskViewModel>(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          // Search
          TextField(
            onChanged: vm.setSearchQuery,
            decoration: InputDecoration(
              hintText: 'Search tasks...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: search.isNotEmpty
                  ? IconButton(
                      onPressed: () => vm.setSearchQuery(''),
                      icon: const Icon(Icons.clear))
                  : null,
              filled: true,
              fillColor: isDark
                  ? Colors.white.withValues(alpha: 0.05)
                  : Colors.black.withValues(alpha: 0.03),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none),
            ),
          ),
          const SizedBox(height: 12),

          // Filter & Sort
          Row(
            children: [
              ...TaskFilter.values.map((f) => Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      label: Text(f.name.toUpperCase()),
                      selected: currentFilter == f,
                      onSelected: (_) => vm.setFilter(f),
                      selectedColor:
                          theme.colorScheme.primary.withValues(alpha: 0.2),
                    ),
                  )),
              const Spacer(),
              PopupMenuButton<TaskSort>(
                initialValue: currentSort,
                onSelected: vm.setSort,
                itemBuilder: (_) => TaskSort.values
                    .map((s) => PopupMenuItem(value: s, child: Text(s.name)))
                    .toList(),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
              ),
            ],
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}
