import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:fluquery/fluquery.dart';

import '../../shared/shared.dart';

/// Demonstrates named services for multi-tenant scenarios.
///
/// **Real-world use cases:**
/// - SaaS apps with multiple tenant APIs
/// - A/B testing with different configurations
/// - Dev/staging/prod environment switching
/// - Multiple payment gateways (Stripe, PayPal)
///
/// **Named services allow:**
/// - Multiple instances of the same type
/// - Each identified by a unique name
/// - Independent lifecycle and state
class MultiTenantScenario extends HookWidget {
  const MultiTenantScenario({super.key});

  @override
  Widget build(BuildContext context) {
    final client = QueryClientProvider.of(context);

    // Active tenant state
    final activeTenant = useState<String?>(null);
    final fetchResult = useState<TenantData?>(null);
    final isLoading = useState(false);

    // Register tenants on mount
    useEffect(() {
      final container = client.services!;

      // Register named services for each tenant
      container.registerNamed<TenantApiClient>(
        'acme',
        (ref) => TenantApiClient(
          tenantId: 'acme',
          displayName: 'Acme Corp',
          baseUrl: 'https://api.acme.com',
          theme: const Color(0xFF3B82F6),
          plan: 'Enterprise',
        ),
      );

      container.registerNamed<TenantApiClient>(
        'globex',
        (ref) => TenantApiClient(
          tenantId: 'globex',
          displayName: 'Globex Inc',
          baseUrl: 'https://api.globex.com',
          theme: const Color(0xFFEC4899),
          plan: 'Professional',
        ),
      );

      container.registerNamed<TenantApiClient>(
        'initech',
        (ref) => TenantApiClient(
          tenantId: 'initech',
          displayName: 'Initech LLC',
          baseUrl: 'https://api.initech.com',
          theme: const Color(0xFF22C55E),
          plan: 'Startup',
        ),
      );

      return () {
        // Cleanup named services on unmount
        container.unregister<TenantApiClient>(name: 'acme');
        container.unregister<TenantApiClient>(name: 'globex');
        container.unregister<TenantApiClient>(name: 'initech');
      };
    }, [client]);

    Future<void> selectTenant(String tenantName) async {
      isLoading.value = true;
      activeTenant.value = tenantName;

      try {
        final container = client.services!;
        final apiClient = container.getSync<TenantApiClient>(name: tenantName);
        final data = await apiClient.fetchDashboard();
        fetchResult.value = data;
      } catch (e) {
        debugPrint('Error: $e');
      } finally {
        isLoading.value = false;
      }
    }

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
                // Tenant selector
                Expanded(
                  child: _TenantSelector(
                    activeTenant: activeTenant.value,
                    isLoading: isLoading.value,
                    onSelect: selectTenant,
                  ),
                ),
                const SizedBox(width: 16),
                // Tenant dashboard
                Expanded(
                  flex: 2,
                  child: _TenantDashboard(
                    tenantName: activeTenant.value,
                    data: fetchResult.value,
                    isLoading: isLoading.value,
                    client: client,
                  ),
                ),
              ],
            ),
          ),
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
          'Multi-Tenant Services',
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Named services allow multiple instances of the same type, '
          'each with its own configuration and state.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
          ),
        ),
      ],
    );
  }
}

// ============================================================
// TENANT API CLIENT - Named service per tenant
// ============================================================

class TenantData {
  final String tenantId;
  final int activeUsers;
  final int totalRequests;
  final double uptime;
  final List<String> recentEvents;

  TenantData({
    required this.tenantId,
    required this.activeUsers,
    required this.totalRequests,
    required this.uptime,
    required this.recentEvents,
  });
}

/// Each tenant gets its own API client instance via named registration.
class TenantApiClient extends Service {
  final String tenantId;
  final String displayName;
  final String baseUrl;
  final Color theme;
  final String plan;

  // Reactive state for this tenant
  final _requestCount = ReactiveState<int>(0);

  TenantApiClient({
    required this.tenantId,
    required this.displayName,
    required this.baseUrl,
    required this.theme,
    required this.plan,
  });

  ValueListenable<int> get requestCount => _requestCount;

  Future<TenantData> fetchDashboard() async {
    _requestCount.value++;

    // Simulate API call
    await Future.delayed(const Duration(milliseconds: 600));

    return TenantData(
      tenantId: tenantId,
      activeUsers: 100 + tenantId.hashCode.abs() % 900,
      totalRequests:
          _requestCount.value * 1000 + tenantId.hashCode.abs() % 5000,
      uptime: 99.0 + (tenantId.hashCode.abs() % 100) / 100,
      recentEvents: [
        'User logged in from ${_cities[tenantId.hashCode.abs() % _cities.length]}',
        'API rate limit updated',
        'New deployment completed',
        'Database backup successful',
      ],
    );
  }

  static const _cities = ['New York', 'London', 'Tokyo', 'Sydney', 'Berlin'];

  @override
  Future<void> onDispose() async {
    _requestCount.dispose();
  }
}

// ============================================================
// UI COMPONENTS
// ============================================================

class _TenantSelector extends StatelessWidget {
  final String? activeTenant;
  final bool isLoading;
  final void Function(String) onSelect;

  const _TenantSelector({
    required this.activeTenant,
    required this.isLoading,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final tenants = [
      (
        'acme',
        'Acme Corp',
        Icons.business_rounded,
        const Color(0xFF3B82F6),
        'Enterprise'
      ),
      (
        'globex',
        'Globex Inc',
        Icons.public_rounded,
        const Color(0xFFEC4899),
        'Professional'
      ),
      (
        'initech',
        'Initech LLC',
        Icons.code_rounded,
        const Color(0xFF22C55E),
        'Startup'
      ),
    ];

    return ThemedCard(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.business_center_rounded,
                    size: 20, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  'Select Tenant',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Each tenant has its own named service instance',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView.separated(
                itemCount: tenants.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final (id, name, icon, color, plan) = tenants[index];
                  final isSelected = activeTenant == id;
                  final isLoadingThis = isLoading && isSelected;

                  return _TenantCard(
                    id: id,
                    name: name,
                    icon: icon,
                    color: color,
                    plan: plan,
                    isSelected: isSelected,
                    isLoading: isLoadingThis,
                    onTap: () => onSelect(id),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TenantCard extends StatelessWidget {
  final String id;
  final String name;
  final IconData icon;
  final Color color;
  final String plan;
  final bool isSelected;
  final bool isLoading;
  final VoidCallback onTap;

  const _TenantCard({
    required this.id,
    required this.name,
    required this.icon,
    required this.color,
    required this.plan,
    required this.isSelected,
    required this.isLoading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Material(
      color: isSelected
          ? color.withValues(alpha: 0.15)
          : (isDark
              ? Colors.white.withValues(alpha: 0.05)
              : Colors.grey.withValues(alpha: 0.05)),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: isLoading ? null : onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected
                  ? color.withValues(alpha: 0.5)
                  : Colors.transparent,
              width: 2,
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Container(
                      margin: const EdgeInsets.only(top: 4),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        plan,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                          color: color,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (isLoading)
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: color,
                  ),
                )
              else if (isSelected)
                Icon(Icons.check_circle_rounded, color: color),
            ],
          ),
        ),
      ),
    );
  }
}

class _TenantDashboard extends HookWidget {
  final String? tenantName;
  final TenantData? data;
  final bool isLoading;
  final QueryClient client;

  const _TenantDashboard({
    required this.tenantName,
    required this.data,
    required this.isLoading,
    required this.client,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (tenantName == null) {
      return ThemedCard(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.touch_app_rounded,
                  size: 48,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.2)),
              const SizedBox(height: 12),
              Text(
                'Select a tenant to view dashboard',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Get tenant service for reactive request count
    TenantApiClient? apiClient;
    try {
      apiClient = client.services!.getSync<TenantApiClient>(name: tenantName);
    } catch (_) {}

    final requestCount =
        apiClient != null ? useValueListenable(apiClient.requestCount) : 0;

    if (isLoading || data == null) {
      return ThemedCard(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text('Loading ${apiClient?.displayName ?? tenantName}...'),
            ],
          ),
        ),
      );
    }

    return ThemedCard(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: (apiClient?.theme ?? Colors.blue)
                        .withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.dashboard_rounded,
                      color: apiClient?.theme ?? Colors.blue, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${apiClient?.displayName} Dashboard',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        apiClient?.baseUrl ?? '',
                        style: theme.textTheme.labelSmall?.copyWith(
                          fontFamily: 'monospace',
                          color: theme.colorScheme.onSurface
                              .withValues(alpha: 0.5),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.blue.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '$requestCount requests',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: Colors.blue,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Stats grid
            Row(
              children: [
                _StatCard(
                  label: 'Active Users',
                  value: data!.activeUsers.toString(),
                  icon: Icons.people_alt_rounded,
                  color: Colors.green,
                ),
                const SizedBox(width: 12),
                _StatCard(
                  label: 'Total Requests',
                  value: '${(data!.totalRequests / 1000).toStringAsFixed(1)}K',
                  icon: Icons.api_rounded,
                  color: Colors.blue,
                ),
                const SizedBox(width: 12),
                _StatCard(
                  label: 'Uptime',
                  value: '${data!.uptime.toStringAsFixed(2)}%',
                  icon: Icons.check_circle_rounded,
                  color: Colors.purple,
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Recent events
            Text(
              'Recent Events',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: ListView.separated(
                itemCount: data!.recentEvents.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Row(
                      children: [
                        Icon(Icons.circle,
                            size: 6,
                            color: theme.colorScheme.onSurface
                                .withValues(alpha: 0.4)),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            data!.recentEvents[index],
                            style: theme.textTheme.bodySmall,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isDark
              ? Colors.white.withValues(alpha: 0.05)
              : Colors.grey.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 10),
            Text(
              value,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              label,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
