import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import '../shared/shared.dart';
import 'widgets/info_card.dart';
import 'widgets/feature_row.dart';
import 'widgets/select_demos.dart';
import 'widgets/keep_previous_demos.dart';

/// Advanced Features Example - demonstrates select, keepPreviousData
class AdvancedFeaturesExample extends HookWidget {
  const AdvancedFeaturesExample({super.key});

  @override
  Widget build(BuildContext context) {
    final tabController = useTabController(initialLength: 3);
    final accentColor = Theme.of(context).colorScheme.primary;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Advanced Features'),
        bottom: TabBar(
          controller: tabController,
          indicatorColor: accentColor,
          tabs: const [
            Tab(icon: Icon(Icons.filter_list), text: 'Select'),
            Tab(icon: Icon(Icons.history), text: 'Keep Previous'),
            Tab(icon: Icon(Icons.compare), text: 'Comparison'),
          ],
        ),
      ),
      body: GradientBackground(
        child: TabBarView(
          controller: tabController,
          children: const [
            _SelectExample(),
            _KeepPreviousDataExample(),
            _ComparisonExample(),
          ],
        ),
      ),
    );
  }
}

class _SelectExample extends HookWidget {
  const _SelectExample();

  @override
  Widget build(BuildContext context) {
    final viewType = useState<String>('names');
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const AdvancedInfoCard(
            icon: Icons.filter_list,
            title: 'Select Function',
            description: 'Transform query data before returning it. '
                'Useful for selecting subsets or computing derived values. '
                'The raw data is still cached, but your component only receives the transformed result.',
          ),
          const SizedBox(height: 16),
          ThemedCard(
            child: Row(
              children: [
                Text(
                  'Select:',
                  style: TextStyle(
                    color: isDark ? Colors.white70 : Colors.black54,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(value: 'names', label: Text('Names Only')),
                      ButtonSegment(
                          value: 'emails', label: Text('Emails Only')),
                      ButtonSegment(value: 'count', label: Text('Count')),
                    ],
                    selected: {viewType.value},
                    onSelectionChanged: (s) => viewType.value = s.first,
                    style: ButtonStyle(
                      foregroundColor: WidgetStateProperty.all(
                        isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (viewType.value == 'names') const SelectNamesDemo(),
          if (viewType.value == 'emails') const SelectEmailsDemo(),
          if (viewType.value == 'count') const SelectCountDemo(),
        ],
      ),
    );
  }
}

class _KeepPreviousDataExample extends HookWidget {
  const _KeepPreviousDataExample();

  @override
  Widget build(BuildContext context) {
    final selectedUserId = useState<int>(1);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accentColor = Theme.of(context).colorScheme.primary;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const AdvancedInfoCard(
            icon: Icons.history,
            title: 'Keep Previous Data',
            description:
                'When changing query keys, keep the previous data visible while fetching new data. '
                'Perfect for paginated UIs where you don\'t want a loading spinner between pages.',
          ),
          const SizedBox(height: 16),
          ThemedCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Select User:',
                  style: TextStyle(
                    color: isDark ? Colors.white70 : Colors.black54,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: List.generate(5, (i) {
                    final userId = i + 1;
                    final isSelected = selectedUserId.value == userId;
                    return ChoiceChip(
                      label: Text('User $userId'),
                      selected: isSelected,
                      onSelected: (_) => selectedUserId.value = userId,
                      selectedColor: accentColor,
                      labelStyle: TextStyle(
                        color: isSelected
                            ? Colors.white
                            : (isDark ? Colors.white70 : Colors.black54),
                      ),
                    );
                  }),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: WithoutKeepPreviousData(userId: selectedUserId.value),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: WithKeepPreviousData(userId: selectedUserId.value),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ComparisonExample extends StatelessWidget {
  const _ComparisonExample();

  @override
  Widget build(BuildContext context) {
    return const SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AdvancedInfoCard(
            icon: Icons.compare,
            title: 'Feature Comparison',
            description: 'When to use each feature for optimal UX.',
          ),
          SizedBox(height: 16),
          FeatureRow(
            feature: 'select',
            description: 'Transform data before returning',
            useCase: 'Selecting subset of fields, computing derived values',
            example: 'users.map((u) => u.name)',
          ),
          SizedBox(height: 12),
          FeatureRow(
            feature: 'keepPreviousData',
            description: 'Keep old data while fetching new',
            useCase: 'Pagination, tab switching, search results',
            example: 'Switching between user profiles',
          ),
          SizedBox(height: 12),
          FeatureRow(
            feature: 'placeholderData',
            description: 'Show placeholder while loading',
            useCase: 'Initial load, skeleton screens',
            example: 'placeholderData: []',
          ),
          SizedBox(height: 12),
          FeatureRow(
            feature: 'initialData',
            description: 'Pre-populate cache',
            useCase: 'Data from parent, SSR hydration',
            example: 'Data passed from list to detail',
          ),
        ],
      ),
    );
  }
}
