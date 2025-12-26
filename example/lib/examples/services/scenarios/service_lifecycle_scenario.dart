import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:fluquery/fluquery.dart';

import '../../shared/shared.dart';

/// Demonstrates service lifecycle management:
/// - onInit: Called when service is first accessed (async setup)
/// - onReset: Clear state without disposing (e.g., on logout)
/// - onDispose: Cleanup when service is destroyed
///
/// Also shows QueryStore integration - stores are auto-disposed with their service.
class ServiceLifecycleScenario extends HookWidget {
  const ServiceLifecycleScenario({super.key});

  @override
  Widget build(BuildContext context) {
    final client = QueryClientProvider.of(context);
    final scope = useMemoized(() {
      return client.services!.createScope();
    }, [client]);

    final lifecycleService = useState<LifecycleExampleService?>(null);
    final logs = useState<List<_LogEntry>>([]);
    final isInitialized = useState(false);

    void log(String message, {Color? color}) {
      logs.value = [
        _LogEntry(message, DateTime.now(), color: color),
        ...logs.value.take(19),
      ];
    }

    Future<void> createService() async {
      log('Registering LifecycleExampleService...', color: Colors.blue);
      scope.register<LifecycleExampleService>(
        (ref) => LifecycleExampleService(log, ref),
      );

      log('Calling initialize()...', color: Colors.blue);
      await scope.initialize();

      log('Getting service instance...', color: Colors.blue);
      final service = scope.get<LifecycleExampleService>();
      lifecycleService.value = service;
      isInitialized.value = true;

      log('Service ready! Store has ${service.store.data?.length ?? 0} items', 
          color: Colors.green);
    }

    Future<void> resetService() async {
      log('Calling reset()...', color: Colors.orange);
      await scope.reset<LifecycleExampleService>();
      log('Service reset complete', color: Colors.orange);
    }

    Future<void> disposeService() async {
      log('Calling dispose()...', color: Colors.red);
      await scope.dispose<LifecycleExampleService>();
      lifecycleService.value = null;
      isInitialized.value = false;
      log('Service disposed', color: Colors.red);
    }

    Future<void> accessStore() async {
      final service = lifecycleService.value;
      if (service == null) {
        log('Service not available!', color: Colors.red);
        return;
      }

      log('Refetching store data...', color: Colors.purple);
      await service.store.refetch();
      log('Store now has ${service.store.data?.length ?? 0} items', 
          color: Colors.purple);
    }

    useEffect(() {
      return () => scope.disposeAll();
    }, [scope]);

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(context),
          const SizedBox(height: 24),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Controls
                Expanded(
                  child: _ControlsPanel(
                    isInitialized: isInitialized.value,
                    service: lifecycleService.value,
                    onCreate: createService,
                    onReset: resetService,
                    onDispose: disposeService,
                    onAccessStore: accessStore,
                  ),
                ),
                const SizedBox(width: 16),
                // Logs
                Expanded(
                  child: _LogsPanel(logs: logs.value),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _LifecycleDiagram(),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Service Lifecycle',
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Explore init, reset, and dispose lifecycle hooks. QueryStores are auto-disposed with their service.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
          ),
        ),
      ],
    );
  }
}

class _ControlsPanel extends StatelessWidget {
  final bool isInitialized;
  final LifecycleExampleService? service;
  final VoidCallback onCreate;
  final VoidCallback onReset;
  final VoidCallback onDispose;
  final VoidCallback onAccessStore;

  const _ControlsPanel({
    required this.isInitialized,
    required this.service,
    required this.onCreate,
    required this.onReset,
    required this.onDispose,
    required this.onAccessStore,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ThemedCard(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.settings_rounded,
                  size: 20,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  'Lifecycle Controls',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Status indicator
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: (isInitialized ? Colors.green : Colors.grey)
                    .withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: (isInitialized ? Colors.green : Colors.grey)
                      .withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: isInitialized ? Colors.green : Colors.grey,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    isInitialized ? 'Service Active' : 'No Service',
                    style: theme.textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: isInitialized ? Colors.green : Colors.grey,
                    ),
                  ),
                  if (isInitialized && service != null) ...[
                    const Spacer(),
                    Text(
                      'Store: ${service!.store.data?.length ?? 0} items',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: Colors.green.withValues(alpha: 0.8),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Lifecycle buttons
            _LifecycleButton(
              icon: Icons.play_arrow_rounded,
              label: 'Create & Initialize',
              description: 'Register service and call onInit()',
              color: Colors.blue,
              onPressed: !isInitialized ? onCreate : null,
            ),
            const SizedBox(height: 12),
            _LifecycleButton(
              icon: Icons.refresh_rounded,
              label: 'Reset',
              description: 'Call onReset() - clears state, keeps instance',
              color: Colors.orange,
              onPressed: isInitialized ? onReset : null,
            ),
            const SizedBox(height: 12),
            _LifecycleButton(
              icon: Icons.stop_rounded,
              label: 'Dispose',
              description: 'Call onDispose() - destroys instance & stores',
              color: Colors.red,
              onPressed: isInitialized ? onDispose : null,
            ),
            const SizedBox(height: 20),

            const Divider(),
            const SizedBox(height: 12),

            // Store operations
            Text(
              'Store Operations',
              style: theme.textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            _LifecycleButton(
              icon: Icons.cloud_download_rounded,
              label: 'Refetch Store',
              description: 'Trigger a new fetch on the service\'s QueryStore',
              color: Colors.purple,
              onPressed: isInitialized ? onAccessStore : null,
            ),
          ],
        ),
      ),
    );
  }
}

class _LifecycleButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final String description;
  final Color color;
  final VoidCallback? onPressed;

  const _LifecycleButton({
    required this.icon,
    required this.label,
    required this.description,
    required this.color,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isEnabled = onPressed != null;

    return Material(
      color: isEnabled
          ? color.withValues(alpha: 0.1)
          : Colors.grey.withValues(alpha: 0.05),
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isEnabled
                      ? color.withValues(alpha: 0.2)
                      : Colors.grey.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  icon,
                  size: 18,
                  color: isEnabled ? color : Colors.grey,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: theme.textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: isEnabled ? null : Colors.grey,
                      ),
                    ),
                    Text(
                      description,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: isEnabled
                            ? theme.colorScheme.onSurface.withValues(alpha: 0.5)
                            : Colors.grey.withValues(alpha: 0.5),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: isEnabled ? color : Colors.grey.withValues(alpha: 0.3),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LogsPanel extends StatelessWidget {
  final List<_LogEntry> logs;

  const _LogsPanel({required this.logs});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return ThemedCard(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.terminal_rounded,
                  size: 20,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  'Lifecycle Events',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                Text(
                  '${logs.length} events',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.black.withValues(alpha: 0.3)
                      : Colors.grey.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.05)
                        : Colors.grey.withValues(alpha: 0.1),
                  ),
                ),
                child: logs.isEmpty
                    ? Center(
                        child: Text(
                          'No events yet.\nClick "Create & Initialize" to start.',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      )
                    : ListView.separated(
                        itemCount: logs.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 6),
                        itemBuilder: (context, index) {
                          final log = logs[index];
                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _formatTime(log.timestamp),
                                style: theme.textTheme.labelSmall?.copyWith(
                                  fontFamily: 'monospace',
                                  color: theme.colorScheme.onSurface
                                      .withValues(alpha: 0.4),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  log.message,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    fontFamily: 'monospace',
                                    color: log.color ??
                                        theme.colorScheme.onSurface,
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime time) {
    return '${time.hour.toString().padLeft(2, '0')}:'
        '${time.minute.toString().padLeft(2, '0')}:'
        '${time.second.toString().padLeft(2, '0')}';
  }
}

class _LifecycleDiagram extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E2E) : const Color(0xFFF8F8FC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.1)
              : Colors.black.withValues(alpha: 0.05),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _DiagramStep(
            number: '1',
            label: 'register()',
            description: 'Define factory',
            color: Colors.grey,
          ),
          _DiagramArrow(),
          _DiagramStep(
            number: '2',
            label: 'get()',
            description: 'Create instance',
            color: Colors.blue,
          ),
          _DiagramArrow(),
          _DiagramStep(
            number: '3',
            label: 'onInit()',
            description: 'Async setup',
            color: Colors.green,
          ),
          _DiagramArrow(),
          _DiagramStep(
            number: '4',
            label: 'onReset()',
            description: 'Clear state',
            color: Colors.orange,
            isOptional: true,
          ),
          _DiagramArrow(),
          _DiagramStep(
            number: '5',
            label: 'onDispose()',
            description: 'Cleanup',
            color: Colors.red,
          ),
        ],
      ),
    );
  }
}

class _DiagramStep extends StatelessWidget {
  final String number;
  final String label;
  final String description;
  final Color color;
  final bool isOptional;

  const _DiagramStep({
    required this.number,
    required this.label,
    required this.description,
    required this.color,
    this.isOptional = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.2),
            shape: BoxShape.circle,
            border: Border.all(color: color, width: 2),
          ),
          child: Center(
            child: Text(
              number,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            fontWeight: FontWeight.w600,
            fontFamily: 'monospace',
          ),
        ),
        Text(
          isOptional ? '(optional)' : description,
          style: theme.textTheme.labelSmall?.copyWith(
            fontSize: 9,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
          ),
        ),
      ],
    );
  }
}

class _DiagramArrow extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Icon(
      Icons.arrow_forward_rounded,
      size: 16,
      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3),
    );
  }
}

class _LogEntry {
  final String message;
  final DateTime timestamp;
  final Color? color;

  _LogEntry(this.message, this.timestamp, {this.color});
}

/// Example service demonstrating lifecycle hooks
class LifecycleExampleService extends Service {
  final void Function(String, {Color? color}) _log;
  late final QueryStore<List<String>, Object> store;
  int _fetchCount = 0;

  LifecycleExampleService(this._log, ServiceRef ref) {
    // Create store in constructor (ref available here)
    store = ref.createStore<List<String>, Object>(
      queryKey: const ['lifecycle', 'demo-data'],
      queryFn: (_) async {
        _fetchCount++;
        await Future.delayed(const Duration(milliseconds: 500));
        return List.generate(
          5,
          (i) => 'Item ${i + 1} (fetch #$_fetchCount)',
        );
      },
    );
  }

  @override
  Future<void> onInit() async {
    _log('→ onInit() started...', color: Colors.green);

    // Simulate async initialization
    await Future.delayed(const Duration(milliseconds: 300));
    await store.refetch();

    _log('→ onInit() complete. Store created with ${store.data?.length ?? 0} items',
        color: Colors.green);
  }

  @override
  Future<void> onReset() async {
    _log('→ onReset() called', color: Colors.orange);
    _fetchCount = 0;
    // Clear store data but don't dispose it
    store.setData([]);
    _log('→ State cleared', color: Colors.orange);
  }

  @override
  Future<void> onDispose() async {
    _log('→ onDispose() called', color: Colors.red);
    // Store will be auto-disposed by container
    _log('→ Cleanup complete (store auto-disposed)', color: Colors.red);
  }
}

