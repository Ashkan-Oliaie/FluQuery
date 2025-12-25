import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:fluquery/fluquery.dart';
import '../api/api_client.dart';

/// Advanced Features Example - demonstrates select, keepPreviousData
class AdvancedFeaturesExample extends HookWidget {
  const AdvancedFeaturesExample({super.key});

  @override
  Widget build(BuildContext context) {
    final tabController = useTabController(initialLength: 3);
    final isDark = Theme.of(context).brightness == Brightness.dark;
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
      body: Container(
        decoration: BoxDecoration(
          gradient: isDark
              ? const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFF0F0F1A), Color(0xFF1A1A2E)],
                )
              : LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.grey.shade50, Colors.white],
                ),
        ),
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
    final accentColor = Theme.of(context).colorScheme.primary;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _InfoCard(
            icon: Icons.filter_list,
            title: 'Select Function',
            description: 'Transform query data before returning it. '
                'Useful for selecting subsets or computing derived values. '
                'The raw data is still cached, but your component only receives the transformed result.',
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark
                  ? Color.lerp(const Color(0xFF1A1A2E), accentColor, 0.05)
                  : Color.lerp(Colors.white, accentColor, 0.03),
              borderRadius: BorderRadius.circular(12),
              border:
                  Border.all(color: accentColor.withAlpha(isDark ? 40 : 25)),
            ),
            child: Row(
              children: [
                Text('Select:',
                    style: TextStyle(
                        color: isDark ? Colors.white70 : Colors.black54)),
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
                          isDark ? Colors.white : Colors.black87),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (viewType.value == 'names') const _SelectNamesDemo(),
          if (viewType.value == 'emails') const _SelectEmailsDemo(),
          if (viewType.value == 'count') const _SelectCountDemo(),
        ],
      ),
    );
  }
}

class _SelectNamesDemo extends HookWidget {
  const _SelectNamesDemo();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accentColor = Theme.of(context).colorScheme.primary;

    final query = useQuerySelect<List<User>, Object, List<String>>(
      queryKey: ['users'],
      queryFn: (_) => ApiClient.getUsers(),
      select: (users) => users.map((u) => u.name).toList(),
    );

    return _ResultCard(
      title: 'User Names (List<String>)',
      isLoading: query.isLoading,
      isFetching: query.isFetching,
      error: query.error?.toString(),
      child: query.data != null
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: query.data!
                  .map((name) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: [
                            Icon(Icons.person, color: accentColor, size: 16),
                            const SizedBox(width: 8),
                            Text(name,
                                style: TextStyle(
                                    color: isDark
                                        ? Colors.white
                                        : Colors.black87)),
                          ],
                        ),
                      ))
                  .toList(),
            )
          : null,
    );
  }
}

class _SelectEmailsDemo extends HookWidget {
  const _SelectEmailsDemo();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accentColor = Theme.of(context).colorScheme.primary;

    final query = useQuerySelect<List<User>, Object, List<String>>(
      queryKey: ['users'],
      queryFn: (_) => ApiClient.getUsers(),
      select: (users) => users.map((u) => u.email).toList(),
    );

    return _ResultCard(
      title: 'User Emails (List<String>)',
      isLoading: query.isLoading,
      isFetching: query.isFetching,
      error: query.error?.toString(),
      child: query.data != null
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: query.data!
                  .map((email) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: [
                            Icon(Icons.email,
                                color:
                                    Color.lerp(accentColor, Colors.green, 0.5),
                                size: 16),
                            const SizedBox(width: 8),
                            Text(email,
                                style: TextStyle(
                                    color: isDark
                                        ? Colors.white
                                        : Colors.black87)),
                          ],
                        ),
                      ))
                  .toList(),
            )
          : null,
    );
  }
}

class _SelectCountDemo extends HookWidget {
  const _SelectCountDemo();

  @override
  Widget build(BuildContext context) {
    final accentColor = Theme.of(context).colorScheme.primary;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final query = useQuerySelect<List<User>, Object, int>(
      queryKey: ['users'],
      queryFn: (_) => ApiClient.getUsers(),
      select: (users) => users.length,
    );

    return _ResultCard(
      title: 'User Count (int)',
      isLoading: query.isLoading,
      isFetching: query.isFetching,
      error: query.error?.toString(),
      child: query.data != null
          ? Center(
              child: Column(
                children: [
                  Text(
                    '${query.data}',
                    style: TextStyle(
                        fontSize: 64,
                        fontWeight: FontWeight.bold,
                        color: accentColor),
                  ),
                  Text('total users',
                      style: TextStyle(
                          color: isDark ? Colors.white54 : Colors.black45)),
                ],
              ),
            )
          : null,
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
          _InfoCard(
            icon: Icons.history,
            title: 'Keep Previous Data',
            description:
                'When changing query keys, keep the previous data visible while fetching new data. '
                'Perfect for paginated UIs where you don\'t want a loading spinner between pages.',
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark
                  ? Color.lerp(const Color(0xFF1A1A2E), accentColor, 0.05)
                  : Color.lerp(Colors.white, accentColor, 0.03),
              borderRadius: BorderRadius.circular(12),
              border:
                  Border.all(color: accentColor.withAlpha(isDark ? 40 : 25)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Select User:',
                    style: TextStyle(
                        color: isDark ? Colors.white70 : Colors.black54)),
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
                  child:
                      _WithoutKeepPreviousData(userId: selectedUserId.value)),
              const SizedBox(width: 12),
              Expanded(
                  child: _WithKeepPreviousData(userId: selectedUserId.value)),
            ],
          ),
        ],
      ),
    );
  }
}

class _WithoutKeepPreviousData extends HookWidget {
  final int userId;
  const _WithoutKeepPreviousData({required this.userId});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final query = useQuery<List<Post>, Object>(
      queryKey: ['user-posts-no-keep', userId],
      queryFn: (_) => ApiClient.getUserPosts(userId),
      keepPreviousData: false,
    );

    return _ResultCard(
      title: '❌ Without keepPreviousData',
      subtitle: query.isFetching ? 'Fetching...' : null,
      isLoading: query.isLoading,
      isFetching: query.isFetching,
      error: query.error?.toString(),
      compact: true,
      child: query.data != null
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: query.data!
                  .take(3)
                  .map((post) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Text(
                          '• ${post.title}',
                          style: TextStyle(
                              color: isDark ? Colors.white70 : Colors.black54,
                              fontSize: 11),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ))
                  .toList(),
            )
          : null,
    );
  }
}

class _WithKeepPreviousData extends HookWidget {
  final int userId;
  const _WithKeepPreviousData({required this.userId});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final query = useQuery<List<Post>, Object>(
      queryKey: ['user-posts-with-keep', userId],
      queryFn: (_) => ApiClient.getUserPosts(userId),
      keepPreviousData: true,
    );

    return _ResultCard(
      title: '✅ With keepPreviousData',
      subtitle: query.isPreviousData
          ? '📍 Showing previous data...'
          : query.isFetching
              ? 'Updating...'
              : null,
      isLoading: query.isLoading,
      isFetching: query.isFetching && !query.isPreviousData,
      isPreviousData: query.isPreviousData,
      error: query.error?.toString(),
      compact: true,
      child: query.data != null
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: query.data!
                  .take(3)
                  .map((post) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Text(
                          '• ${post.title}',
                          style: TextStyle(
                            color: query.isPreviousData
                                ? (isDark ? Colors.white38 : Colors.black26)
                                : (isDark ? Colors.white70 : Colors.black54),
                            fontSize: 11,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ))
                  .toList(),
            )
          : null,
    );
  }
}

class _ComparisonExample extends HookWidget {
  const _ComparisonExample();

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          _InfoCard(
            icon: Icons.compare,
            title: 'Feature Comparison',
            description: 'When to use each feature for optimal UX.',
          ),
          SizedBox(height: 16),
          _FeatureRow(
            feature: 'select',
            description: 'Transform data before returning',
            useCase: 'Selecting subset of fields, computing derived values',
            example: 'users.map((u) => u.name)',
          ),
          SizedBox(height: 12),
          _FeatureRow(
            feature: 'keepPreviousData',
            description: 'Keep old data while fetching new',
            useCase: 'Pagination, tab switching, search results',
            example: 'Switching between user profiles',
          ),
          SizedBox(height: 12),
          _FeatureRow(
            feature: 'placeholderData',
            description: 'Show placeholder while loading',
            useCase: 'Initial load, skeleton screens',
            example: 'placeholderData: []',
          ),
          SizedBox(height: 12),
          _FeatureRow(
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

// ============ Helper Widgets ============

class _InfoCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;

  const _InfoCard(
      {required this.icon, required this.title, required this.description});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accentColor = Theme.of(context).colorScheme.primary;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: accentColor.withAlpha(isDark ? 25 : 15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: accentColor.withAlpha(77)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: accentColor, size: 20),
              const SizedBox(width: 8),
              Text(title,
                  style: TextStyle(
                      color: isDark ? Colors.white : Colors.black87,
                      fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 8),
          Text(description,
              style: TextStyle(
                  color: isDark ? Colors.white70 : Colors.black54,
                  fontSize: 13)),
        ],
      ),
    );
  }
}

class _ResultCard extends StatelessWidget {
  final String title;
  final String? subtitle;
  final bool isLoading;
  final bool isFetching;
  final bool isPreviousData;
  final String? error;
  final Widget? child;
  final bool compact;

  const _ResultCard({
    required this.title,
    this.subtitle,
    this.isLoading = false,
    this.isFetching = false,
    this.isPreviousData = false,
    this.error,
    this.child,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accentColor = Theme.of(context).colorScheme.primary;

    return Container(
      padding: EdgeInsets.all(compact ? 12 : 16),
      decoration: BoxDecoration(
        color: isDark
            ? Color.lerp(const Color(0xFF1A1A2E), accentColor, 0.04)
            : Color.lerp(Colors.white, accentColor, 0.02),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isPreviousData
              ? Colors.orange.withAlpha(128)
              : accentColor.withAlpha(isDark ? 35 : 20),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: isDark ? Colors.white : Colors.black87,
                    fontWeight: FontWeight.bold,
                    fontSize: compact ? 12 : 14,
                  ),
                ),
              ),
              if (isFetching && !isLoading)
                SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: accentColor)),
            ],
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(subtitle!,
                style: TextStyle(
                    color: isPreviousData
                        ? Colors.orange
                        : (isDark ? Colors.white54 : Colors.black45),
                    fontSize: 11)),
          ],
          const SizedBox(height: 12),
          if (isLoading)
            Center(child: CircularProgressIndicator(color: accentColor))
          else if (error != null)
            Text(error!, style: const TextStyle(color: Colors.red))
          else if (child != null)
            child!
          else
            Text('No data',
                style:
                    TextStyle(color: isDark ? Colors.white38 : Colors.black26)),
        ],
      ),
    );
  }
}

class _FeatureRow extends StatelessWidget {
  final String feature;
  final String description;
  final String useCase;
  final String example;

  const _FeatureRow({
    required this.feature,
    required this.description,
    required this.useCase,
    required this.example,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accentColor = Theme.of(context).colorScheme.primary;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark
            ? Color.lerp(const Color(0xFF1A1A2E), accentColor, 0.04)
            : Color.lerp(Colors.white, accentColor, 0.02),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: accentColor.withAlpha(isDark ? 30 : 18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: accentColor.withAlpha(51),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  feature,
                  style: TextStyle(
                      color: accentColor,
                      fontFamily: 'monospace',
                      fontWeight: FontWeight.bold,
                      fontSize: 12),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(description,
                    style: TextStyle(
                        color: isDark ? Colors.white : Colors.black87,
                        fontSize: 12)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text('📌 Use case: $useCase',
              style: TextStyle(
                  color: isDark ? Colors.white54 : Colors.black45,
                  fontSize: 11)),
          Text('📝 Example: $example',
              style: TextStyle(
                  color: isDark ? Colors.white38 : Colors.black26,
                  fontSize: 11,
                  fontFamily: 'monospace')),
        ],
      ),
    );
  }
}
