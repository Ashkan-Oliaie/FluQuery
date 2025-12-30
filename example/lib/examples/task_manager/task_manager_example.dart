import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:fluquery/fluquery.dart';

import '../shared/shared.dart';
import 'task_service.dart';
import 'widgets/task_header.dart';
import 'widgets/task_filter_bar.dart';
import 'widgets/task_list.dart';
import 'widgets/add_task_fab.dart';
import 'widgets/stats_panel.dart';

class TaskManagerExample extends HookWidget {
  const TaskManagerExample({super.key});

  @override
  Widget build(BuildContext context) {
    debugPrint('🔄 BUILD: TaskManagerExample');

    final services = useQueryClient().services!;
    final isReady = useState(false);

    useEffect(() {
      Future<void> init() async {
        services
          ..registerNamed<AnalyticsService>(kAnalytics, (_) => AnalyticsService())
          ..registerNamed<StatsService>(kStats, (_) => StatsService())
          ..registerNamed<UndoService>(kUndo, (_) => UndoService())
          ..registerNamed<TaskService>(kTaskService, (_) => TaskService());

        await services.initialize();
        isReady.value = true;
      }

      init();

      return () {
        services
          ..unregister<TaskService>(name: kTaskService)
          ..unregister<UndoService>(name: kUndo)
          ..unregister<StatsService>(name: kStats)
          ..unregister<AnalyticsService>(name: kAnalytics);
      };
    }, const []);

    if (!isReady.value) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return const _TaskManagerContent();
  }
}

class _TaskManagerContent extends StatelessWidget {
  const _TaskManagerContent();

  @override
  Widget build(BuildContext context) {
    debugPrint('🔄 BUILD: _TaskManagerContent');

    return const Scaffold(
      body: GradientBackground(
        child: SafeArea(
          child: Row(
            children: [
              Expanded(
                flex: 2,
                child: Column(
                  children: [
                    TaskHeader(),
                    TaskFilterBar(),
                    Expanded(child: TaskList()),
                  ],
                ),
              ),
              StatsPanel(),
            ],
          ),
        ),
      ),
      floatingActionButton: AddTaskFab(),
    );
  }
}
