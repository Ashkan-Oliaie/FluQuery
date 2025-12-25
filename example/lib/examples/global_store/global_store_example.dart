import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:fluquery/fluquery.dart';
import '../../api/api_client.dart';
import '../../main.dart' show GlobalConfigStore;

/// The Global Store Example Page - demonstrates the QueryStore API
class GlobalStoreExample extends HookWidget {
  const GlobalStoreExample({super.key});

  @override
  Widget build(BuildContext context) {
    final store = GlobalConfigStore.store;
    final configState = useState<QueryState<AppConfig, Object>?>(store?.state);
    final isPaused = useState(false);

    // Subscribe to store changes
    useEffect(() {
      if (store == null) return null;

      final unsubscribe = store.subscribe((state) {
        configState.value = state;
      });

      return unsubscribe;
    }, [store]);

    final config = configState.value?.rawData as AppConfig?;
    final isFetching = configState.value?.isFetching ?? false;
    final isLoading = configState.value?.isLoading ?? true;

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accentColor = Theme.of(context).colorScheme.primary;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F0F1A) : Colors.grey[100],
      appBar: AppBar(
        title: const Text('Global Store'),
        backgroundColor: Colors.transparent,
        actions: [
          IconButton(
            icon: Icon(
              isPaused.value ? Icons.play_arrow : Icons.pause,
              color: isPaused.value
                  ? const Color(0xFF22C55E)
                  : (isDark ? Colors.white70 : Colors.black54),
            ),
            onPressed: () {
              if (isPaused.value) {
                store?.resumeRefetching();
              } else {
                store?.stopRefetching();
              }
              isPaused.value = !isPaused.value;
            },
            tooltip: isPaused.value ? 'Resume polling' : 'Pause polling',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _InfoCard(
              title: 'QueryStore Demo',
              description:
                  'This page shows the same global store that powers the header bar. '
                  'Changes here affect the entire app\'s theme! '
                  'The store polls every 10 seconds and persists across all pages.',
              icon: Icons.info_outline,
              color: accentColor,
            ),
            const SizedBox(height: 24),
            if (isLoading && config == null)
              Center(
                child: CircularProgressIndicator(color: accentColor),
              )
            else if (config != null) ...[
              _ConfigDisplay(config: config, isFetching: isFetching),
              const SizedBox(height: 24),
              _StoreControls(
                store: store!,
                isPaused: isPaused.value,
                onPauseToggle: () {
                  if (isPaused.value) {
                    store.resumeRefetching();
                  } else {
                    store.stopRefetching();
                  }
                  isPaused.value = !isPaused.value;
                },
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final String title;
  final String description;
  final IconData icon;
  final Color color;

  const _InfoCard({
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withAlpha(20),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withAlpha(60)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: color,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Colors.white70
                        : Colors.black54,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ConfigDisplay extends StatelessWidget {
  final AppConfig config;
  final bool isFetching;

  const _ConfigDisplay({
    required this.config,
    required this.isFetching,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accentColor = Theme.of(context).colorScheme.primary;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark
            ? Color.lerp(const Color(0xFF1A1A2E), accentColor, 0.06)
            : Color.lerp(Colors.white, accentColor, 0.03),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accentColor.withAlpha(60)),
        boxShadow: [
          BoxShadow(
            color: accentColor.withAlpha(isDark ? 20 : 25),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Current Config',
                style: TextStyle(
                  color: isDark ? Colors.white : Colors.black87,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              if (isFetching)
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: accentColor,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 20),
          _ConfigRow(
            label: 'Theme',
            value: config.theme,
            icon: Icons.palette_outlined,
          ),
          _ConfigRow(
            label: 'Accent Color',
            value: config.accentColor,
            icon: Icons.color_lens_outlined,
            trailing: Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                color: accentColor,
                shape: BoxShape.circle,
              ),
            ),
          ),
          _ConfigRow(
            label: 'Font Size',
            value: config.fontSize,
            icon: Icons.text_fields,
          ),
          _ConfigRow(
            label: 'Compact Mode',
            value: config.compactMode ? 'Enabled' : 'Disabled',
            icon: Icons.view_compact_outlined,
          ),
          _ConfigRow(
            label: 'Animations',
            value: config.animationsEnabled ? 'Enabled' : 'Disabled',
            icon: Icons.animation,
          ),
          Divider(
            color: isDark ? const Color(0x33FFFFFF) : Colors.grey.shade200,
            height: 24,
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Version: ${config.version}',
                style: TextStyle(
                  color: isDark ? Colors.white38 : Colors.black38,
                  fontSize: 12,
                ),
              ),
              Text(
                'Updated: ${_formatTime(config.updatedAt)}',
                style: TextStyle(
                  color: isDark ? Colors.white38 : Colors.black38,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);
    if (diff.inSeconds < 60) return '${diff.inSeconds}s ago';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    return '${diff.inHours}h ago';
  }
}

class _ConfigRow extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Widget? trailing;

  const _ConfigRow({
    required this.label,
    required this.value,
    required this.icon,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(
            icon,
            color: isDark ? Colors.white54 : Colors.black45,
            size: 20,
          ),
          const SizedBox(width: 12),
          Text(
            label,
            style: TextStyle(
              color: isDark ? Colors.white60 : Colors.black54,
              fontSize: 14,
            ),
          ),
          const Spacer(),
          if (trailing != null) ...[
            trailing!,
            const SizedBox(width: 8),
          ],
          Text(
            value,
            style: TextStyle(
              color: isDark ? Colors.white : Colors.black87,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _StoreControls extends HookWidget {
  final QueryStore<AppConfig, Object> store;
  final bool isPaused;
  final VoidCallback onPauseToggle;

  const _StoreControls({
    required this.store,
    required this.isPaused,
    required this.onPauseToggle,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accentColor = Theme.of(context).colorScheme.primary;
    final isRandomizing = useState(false);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark
            ? Color.lerp(const Color(0xFF1A1A2E), accentColor, 0.04)
            : Color.lerp(Colors.white, accentColor, 0.02),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: accentColor.withAlpha(isDark ? 35 : 20),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Store Controls',
            style: TextStyle(
              color: isDark ? Colors.white : Colors.black87,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _ControlButton(
                icon: isPaused ? Icons.play_arrow : Icons.pause,
                label: isPaused ? 'Resume' : 'Pause',
                color: const Color(0xFF22C55E),
                onTap: onPauseToggle,
              ),
              _ControlButton(
                icon: Icons.refresh,
                label: 'Refetch',
                color: const Color(0xFF3B82F6),
                onTap: () => store.refetch(),
              ),
              _ControlButton(
                icon: Icons.shuffle,
                label: 'Randomize',
                color: const Color(0xFF8B5CF6),
                isLoading: isRandomizing.value,
                onTap: () async {
                  isRandomizing.value = true;
                  try {
                    final newConfig = await ApiClient.randomizeConfig();
                    store.setData(newConfig);
                  } finally {
                    isRandomizing.value = false;
                  }
                },
              ),
              _ControlButton(
                icon: Icons.warning_amber,
                label: 'Invalidate',
                color: const Color(0xFFF59E0B),
                onTap: () => store.invalidate(),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withAlpha(5) : Colors.grey.shade100,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(
                  isPaused ? Icons.pause_circle : Icons.sync,
                  color: isPaused
                      ? const Color(0xFFF59E0B)
                      : const Color(0xFF22C55E),
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  isPaused ? 'Polling paused' : 'Polling every 10 seconds',
                  style: TextStyle(
                    color: isDark ? Colors.white60 : Colors.black54,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ControlButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  final bool isLoading;

  const _ControlButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: isLoading ? null : onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: color.withAlpha(20),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: color.withAlpha(60)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isLoading)
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: color,
                  ),
                )
              else
                Icon(icon, color: color, size: 16),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
