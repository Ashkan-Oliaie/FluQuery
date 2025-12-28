import 'package:flutter/material.dart';
import 'package:fluquery/fluquery.dart';

import '../shared/shared.dart';
import 'task_viewmodel.dart';
import 'widgets/task_header.dart';
import 'widgets/task_filter_bar.dart';
import 'widgets/task_list.dart';
import 'widgets/add_task_fab.dart';
import 'widgets/stats_panel.dart';

/// Task Manager - ViewModel Pattern with Multiple Services
///
/// Services involved:
/// - TaskViewModel: Main screen ViewModel (named service per screen)
/// - AnalyticsService: Tracks all user events
/// - StatsService: Tracks productivity stats
/// - UndoService: Manages undo/redo history
///
/// All services show in devtools!
class ViewModelExample extends StatefulWidget {
  const ViewModelExample({super.key});

  @override
  State<ViewModelExample> createState() => _ViewModelExampleState();
}

class _ViewModelExampleState extends State<ViewModelExample> {
  bool _servicesReady = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _registerServices());
  }

  Future<void> _registerServices() async {
    final client = QueryClientProvider.of(context);
    final services = client.services!;

    // Register supporting services (singletons - shared across screens)
    if (!services.has<AnalyticsService>()) {
      services.register<AnalyticsService>((ref) => AnalyticsService());
    }
    if (!services.has<StatsService>()) {
      services.register<StatsService>((ref) => StatsService());
    }
    if (!services.has<UndoService>()) {
      services.register<UndoService>((ref) => UndoService());
    }

    // Initialize all services
    await services.initialize();

    if (mounted) setState(() => _servicesReady = true);
  }

  @override
  Widget build(BuildContext context) {
    if (!_servicesReady) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    // TaskViewModel is a named service (per-screen instance)
    return ViewModelProvider<TaskViewModel>(
      name: 'task-manager',
      create: (ref) => TaskViewModel(ref),
      child: Scaffold(
        body: GradientBackground(
          child: SafeArea(
            child: Row(
              children: [
                // Main content
                const Expanded(
                  flex: 2,
                  child: Column(
                    children: [
                      TaskHeader(),
                      TaskFilterBar(),
                      Expanded(child: TaskList()),
                    ],
                  ),
                ),
                // Stats panel (shows service data)
                const StatsPanel(),
              ],
            ),
          ),
        ),
        floatingActionButton: const AddTaskFab(),
      ),
    );
  }
}
