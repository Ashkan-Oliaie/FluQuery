import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:fluquery/fluquery.dart';
import '../../api/api_client.dart';
import '../../main.dart' show GlobalConfigStore;
import '../shared/shared.dart';
import 'widgets/store_info_card.dart';
import 'widgets/config_display.dart';
import 'widgets/store_controls.dart';

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
            StoreInfoCard(
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
              const LoadingIndicator()
            else if (config != null) ...[
              ConfigDisplay(config: config, isFetching: isFetching),
              const SizedBox(height: 24),
              StoreControls(
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
