import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import '../shared/shared.dart';
import 'tabs/search_demo.dart';
import 'tabs/filter_demo.dart';
import 'tabs/cancellation_demo.dart';

/// Race Condition Examples - demonstrates different scenarios
class RaceConditionExample extends HookWidget {
  const RaceConditionExample({super.key});

  @override
  Widget build(BuildContext context) {
    final tabController = useTabController(initialLength: 3);
    final accentColor = Theme.of(context).colorScheme.primary;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Race Condition Handling'),
        bottom: TabBar(
          controller: tabController,
          indicatorColor: accentColor,
          tabs: const [
            Tab(icon: Icon(Icons.search), text: 'Search'),
            Tab(icon: Icon(Icons.filter_list), text: 'Filters'),
            Tab(icon: Icon(Icons.cancel), text: 'Cancellation'),
          ],
        ),
      ),
      body: GradientBackground(
        child: TabBarView(
          controller: tabController,
          children: const [
            SearchRaceConditionDemo(),
            FilterRaceConditionDemo(),
            ManualCancellationDemo(),
          ],
        ),
      ),
    );
  }
}
