import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:fluquery/fluquery.dart';

import '../../shared/shared.dart';
import '../widgets/code_block.dart';

/// Demonstrates named services for multi-tenant scenarios.
///
/// Real-world use cases:
/// - SaaS apps with multiple tenant APIs
/// - A/B testing with different service configurations
/// - Dev/staging/prod environment switching
/// - Multiple payment gateways (Stripe, PayPal)
class MultiTenantScenario extends HookWidget {
  const MultiTenantScenario({super.key});

  @override
  Widget build(BuildContext context) {
    final client = QueryClientProvider.of(context);
    final scope = useMemoized(() {
      final s = client.services!.createScope();
      // Register named API clients for different tenants
      s.registerNamed<TenantApiClient>(
        'acme',
        (ref) => TenantApiClient(
          tenantId: 'acme',
          baseUrl: 'https://api.acme.com',
          theme: const Color(0xFF3B82F6),
        ),
      );
      s.registerNamed<TenantApiClient>(
        'globex',
        (ref) => TenantApiClient(
          tenantId: 'globex',
          baseUrl: 'https://api.globex.com',
          theme: const Color(0xFFEC4899),
        ),
      );
      s.registerNamed<TenantApiClient>(
        'initech',
        (ref) => TenantApiClient(
          tenantId: 'initech',
          baseUrl: 'https://api.initech.com',
          theme: const Color(0xFF22C55E),
        ),
      );
      return s;
    }, [client]);

    useEffect(() {
      scope.initialize();
      return () => scope.disposeAll();
    }, [scope]);

    final selectedTenant = useState<String?>(null);
    final fetchResult = useState<String?>(null);
    final isLoading = useState(false);

    Future<void> fetchFromTenant(String tenantName) async {
      isLoading.value = true;
      selectedTenant.value = tenantName;

      try {
        final apiClient = scope.get<TenantApiClient>(name: tenantName);
        final result = await apiClient.fetchData();
        fetchResult.value = result;
      } catch (e) {
        fetchResult.value = 'Error: $e';
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
                    selectedTenant: selectedTenant.value,
                    isLoading: isLoading.value,
                    onSelect: fetchFromTenant,
                    scope: scope,
                  ),
                ),
                const SizedBox(width: 16),
                // Result panel
                Expanded(
                  child: _ResultPanel(
                    selectedTenant: selectedTenant.value,
                    result: fetchResult.value,
                    isLoading: isLoading.value,
                    scope: scope,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const _CodeExample(),
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
          'Use named registrations to manage multiple instances of the same service type.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
          ),
        ),
      ],
    );
  }
}

class _TenantSelector extends StatelessWidget {
  final String? selectedTenant;
  final bool isLoading;
  final void Function(String) onSelect;
  final ServiceContainer scope;

  const _TenantSelector({
    required this.selectedTenant,
    required this.isLoading,
    required this.onSelect,
    required this.scope,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final tenants = [
      _TenantInfo(
        name: 'acme',
        displayName: 'Acme Corp',
        icon: Icons.business_rounded,
        color: const Color(0xFF3B82F6),
        description: 'Enterprise solutions',
      ),
      _TenantInfo(
        name: 'globex',
        displayName: 'Globex Inc',
        icon: Icons.public_rounded,
        color: const Color(0xFFEC4899),
        description: 'Global operations',
      ),
      _TenantInfo(
        name: 'initech',
        displayName: 'Initech LLC',
        icon: Icons.code_rounded,
        color: const Color(0xFF22C55E),
        description: 'Tech startup',
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
                Icon(
                  Icons.business_center_rounded,
                  size: 20,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  'Select Tenant',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...tenants.map((tenant) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _TenantCard(
                    tenant: tenant,
                    isSelected: selectedTenant == tenant.name,
                    isLoading: isLoading && selectedTenant == tenant.name,
                    onTap: () => onSelect(tenant.name),
                  ),
                )),
          ],
        ),
      ),
    );
  }
}

class _TenantInfo {
  final String name;
  final String displayName;
  final IconData icon;
  final Color color;
  final String description;

  _TenantInfo({
    required this.name,
    required this.displayName,
    required this.icon,
    required this.color,
    required this.description,
  });
}

class _TenantCard extends StatelessWidget {
  final _TenantInfo tenant;
  final bool isSelected;
  final bool isLoading;
  final VoidCallback onTap;

  const _TenantCard({
    required this.tenant,
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
          ? tenant.color.withValues(alpha: 0.15)
          : (isDark
              ? Colors.white.withValues(alpha: 0.05)
              : Colors.grey.withValues(alpha: 0.05)),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: isLoading ? null : onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected
                  ? tenant.color.withValues(alpha: 0.5)
                  : Colors.transparent,
              width: 2,
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: tenant.color.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(tenant.icon, color: tenant.color),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tenant.displayName,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      tenant.description,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
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
                    color: tenant.color,
                  ),
                )
              else if (isSelected)
                Icon(
                  Icons.check_circle_rounded,
                  color: tenant.color,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ResultPanel extends StatelessWidget {
  final String? selectedTenant;
  final String? result;
  final bool isLoading;
  final ServiceContainer scope;

  const _ResultPanel({
    required this.selectedTenant,
    required this.result,
    required this.isLoading,
    required this.scope,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (selectedTenant == null) {
      return ThemedCard(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.touch_app_rounded,
                size: 48,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.2),
              ),
              const SizedBox(height: 12),
              Text(
                'Select a tenant to fetch data',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                ),
              ),
            ],
          ),
        ),
      );
    }

    TenantApiClient? apiClient;
    try {
      apiClient = scope.get<TenantApiClient>(name: selectedTenant);
    } catch (_) {}

    return ThemedCard(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: (apiClient?.theme ?? Colors.grey).withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.cloud_done_rounded,
                    size: 16,
                    color: apiClient?.theme ?? Colors.grey,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'API Response',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        apiClient?.baseUrl ?? '',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                          fontFamily: 'monospace',
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(height: 1),
            const SizedBox(height: 16),
            Expanded(
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: theme.colorScheme.outline.withValues(alpha: 0.2),
                  ),
                ),
                child: isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : SingleChildScrollView(
                        child: Text(
                          result ?? '',
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontFamily: 'monospace',
                          ),
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CodeExample extends StatelessWidget {
  const _CodeExample();

  @override
  Widget build(BuildContext context) {
    return const CodeBlock(
      title: 'Named Services - Multi-Tenant Pattern',
      code: '''// Register multiple instances of the same type
container.registerNamed<ApiClient>(
  'acme',
  (ref) => ApiClient(baseUrl: 'api.acme.com'),
);
container.registerNamed<ApiClient>(
  'globex', 
  (ref) => ApiClient(baseUrl: 'api.globex.com'),
);

// Get specific instance by name
final acmeApi = container.get<ApiClient>(name: 'acme');
final globexApi = container.get<ApiClient>(name: 'globex');

// Each is a separate singleton
assert(!identical(acmeApi, globexApi));''',
    );
  }
}

/// Example tenant-specific API client service
class TenantApiClient extends Service {
  final String tenantId;
  final String baseUrl;
  final Color theme;

  TenantApiClient({
    required this.tenantId,
    required this.baseUrl,
    required this.theme,
  });

  Future<String> fetchData() async {
    // Simulate API call
    await Future.delayed(const Duration(milliseconds: 800));

    return '''
{
  "tenant": "$tenantId",
  "endpoint": "$baseUrl/api/v1/data",
  "timestamp": "${DateTime.now().toIso8601String()}",
  "data": {
    "message": "Hello from $tenantId!",
    "activeUsers": ${100 + tenantId.hashCode % 900},
    "apiVersion": "2.1.0"
  }
}''';
  }
}

