import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:fluquery/fluquery.dart';

import '../../api/api_client.dart';
import '../../services/services.dart';
import '../shared/shared.dart';
import 'widgets/store_info_card.dart';
import 'widgets/config_display.dart';
import 'widgets/store_controls.dart';

/// The Global Config Example Page - demonstrates StatefulService with polling
class GlobalStoreExample extends HookWidget {
  const GlobalStoreExample({super.key});

  @override
  Widget build(BuildContext context) {
    // Get service and select state
    final configService = useService<ConfigService>();
    final config =
        useSelect<ConfigService, ConfigState, AppConfig?>((s) => s.config);
    final isLoading =
        useSelect<ConfigService, ConfigState, bool>((s) => s.isLoading);
    final isPaused =
        useSelect<ConfigService, ConfigState, bool>((s) => s.isPaused);

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accentColor = Theme.of(context).colorScheme.primary;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F0F1A) : Colors.grey[100],
      appBar: AppBar(
        title: const Text('Global Config (StatefulService)'),
        backgroundColor: Colors.transparent,
        actions: [
          IconButton(
            icon: Icon(
              isPaused ? Icons.play_arrow : Icons.pause,
              color: isPaused
                  ? const Color(0xFF22C55E)
                  : (isDark ? Colors.white70 : Colors.black54),
            ),
            onPressed: configService.togglePause,
            tooltip: isPaused ? 'Resume polling' : 'Pause polling',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            StoreInfoCard(
              title: 'StatefulService Demo',
              description:
                  'This page uses ConfigService - a StatefulService with single immutable state. '
                  'Changes here affect the entire app\'s theme! '
                  'Uses useSelect for granular rebuilds and background polling every 10 seconds.',
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
                isPaused: isPaused,
                onPauseToggle: configService.togglePause,
                onRefresh: configService.refresh,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
