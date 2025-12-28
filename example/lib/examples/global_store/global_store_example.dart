import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import '../../api/api_client.dart';
import '../../main.dart' show GlobalConfigStore;
import '../shared/shared.dart';
import 'widgets/store_info_card.dart';
import 'widgets/config_display.dart';
import 'widgets/store_controls.dart';

/// The Global Store Example Page - demonstrates global reactive state
class GlobalStoreExample extends HookWidget {
  const GlobalStoreExample({super.key});

  @override
  Widget build(BuildContext context) {
    final config = useValueListenable(GlobalConfigStore.configNotifier);
    final isLoading = useValueListenable(GlobalConfigStore.isLoadingNotifier);
    final isPaused = useState(GlobalConfigStore.isPaused);

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accentColor = Theme.of(context).colorScheme.primary;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F0F1A) : Colors.grey[100],
      appBar: AppBar(
        title: const Text('Global State'),
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
                GlobalConfigStore.resume();
              } else {
                GlobalConfigStore.pause();
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
            StoreInfoCard(
              title: 'Global State Demo',
              description:
                  'This page shows the same global state that powers the header bar. '
                  'Changes here affect the entire app\'s theme! '
                  'The state polls every 10 seconds and persists across all pages.',
              icon: Icons.info_outline,
              color: accentColor,
            ),
            const SizedBox(height: 24),
            if (isLoading && config == null)
              const LoadingIndicator()
            else if (config != null) ...[
              ConfigDisplay(config: config, isFetching: isLoading),
              const SizedBox(height: 24),
              StoreControls(
                isPaused: isPaused.value,
                onPauseToggle: () {
                  if (isPaused.value) {
                    GlobalConfigStore.resume();
                  } else {
                    GlobalConfigStore.pause();
                  }
                  isPaused.value = !isPaused.value;
                },
                onRefresh: GlobalConfigStore.refresh,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
