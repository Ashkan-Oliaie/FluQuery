import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:fluquery/fluquery.dart';

import '../../services/services.dart';
import '../shared/shared.dart';
import 'scenarios/auth_flow_scenario.dart';
import 'scenarios/multi_tenant_scenario.dart';
import 'scenarios/factory_scenario.dart';

/// Comprehensive example demonstrating FluQuery's Service Layer.
///
/// This example uses a side navigation to showcase different real-world scenarios:
/// 1. Authentication Flow - Login, verification, session management
/// 2. Multi-Tenant - Named services for different API environments
/// 3. Factory Pattern - Screen-scoped services with isolated state
class ServicesExample extends HookWidget {
  const ServicesExample({super.key});

  @override
  Widget build(BuildContext context) {
    final selectedIndex = useState(0);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final scenarios = [
      _ScenarioItem(
        icon: Icons.login_rounded,
        title: 'Auth Flow',
        subtitle: 'Login → Verify → Session',
        color: const Color(0xFF22C55E),
      ),
      _ScenarioItem(
        icon: Icons.business_rounded,
        title: 'Multi-Tenant',
        subtitle: 'Named services per tenant',
        color: const Color(0xFF3B82F6),
      ),
      _ScenarioItem(
        icon: Icons.view_module_rounded,
        title: 'Factory',
        subtitle: 'Screen-scoped services',
        color: const Color(0xFFF59E0B),
      ),
    ];

    Widget buildContent() {
      return switch (selectedIndex.value) {
        0 => const AuthFlowScenario(),
        1 => const MultiTenantScenario(),
        2 => const FactoryScenario(),
        _ => const SizedBox.shrink(),
      };
    }

    return Scaffold(
      body: GradientBackground(
        child: SafeArea(
          child: Row(
            children: [
              // Side Navigation
              Container(
                width: 200,
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.black.withValues(alpha: 0.3)
                      : Colors.white.withValues(alpha: 0.7),
                  border: Border(
                    right: BorderSide(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.1)
                          : Colors.black.withValues(alpha: 0.05),
                    ),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          IconButton(
                            onPressed: () => Navigator.pop(context),
                            icon: Icon(
                              Icons.arrow_back,
                              color: isDark ? Colors.white70 : Colors.black54,
                            ),
                            iconSize: 20,
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Services',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Divider(
                      height: 1,
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.1)
                          : Colors.black.withValues(alpha: 0.05),
                    ),
                    const SizedBox(height: 8),

                    // Scenario List
                    ...List.generate(scenarios.length, (index) {
                      final item = scenarios[index];
                      final isSelected = selectedIndex.value == index;

                      return _NavItem(
                        icon: item.icon,
                        title: item.title,
                        subtitle: item.subtitle,
                        color: item.color,
                        isSelected: isSelected,
                        onTap: () => selectedIndex.value = index,
                      );
                    }),

                    const Spacer(),

                    // Status indicator
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: _ServiceStatusBadge(),
                    ),
                  ],
                ),
              ),

              // Content Area
              Expanded(
                child: buildContent(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ScenarioItem {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;

  _ScenarioItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
  });
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final bool isSelected;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: Material(
        color: isSelected ? color.withValues(alpha: 0.15) : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? color.withValues(alpha: 0.2)
                        : (isDark
                            ? Colors.white.withValues(alpha: 0.05)
                            : Colors.black.withValues(alpha: 0.05)),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Icon(
                    icon,
                    size: 16,
                    color: isSelected
                        ? color
                        : (isDark ? Colors.white54 : Colors.black45),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight:
                              isSelected ? FontWeight.w600 : FontWeight.w500,
                          color: isSelected
                              ? color
                              : (isDark ? Colors.white : Colors.black87),
                        ),
                      ),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 10,
                          color: isDark ? Colors.white38 : Colors.black38,
                        ),
                      ),
                    ],
                  ),
                ),
                if (isSelected)
                  Container(
                    width: 3,
                    height: 20,
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ServiceStatusBadge extends HookWidget {
  @override
  Widget build(BuildContext context) {
    // Safely get client and check if services exist
    final client = QueryClientProvider.of(context);
    final services = client.services;

    // If services not ready, show loading state
    if (services == null || !services.isInitialized) {
      return _buildBadge('Initializing...', Colors.grey);
    }

    // Check if session service is available
    try {
      services.getSync<SessionService>();
    } catch (_) {
      return _buildBadge('No Session', Colors.grey);
    }

    // Select status from session service
    final status =
        useSelect<SessionService, SessionState, SessionStatus>((s) => s.status);

    final (statusText, statusColor) = switch (status) {
      SessionStatus.unknown => ('Loading...', Colors.grey),
      SessionStatus.unauthenticated => ('Logged Out', Colors.orange),
      SessionStatus.pendingVerification => ('Verifying...', Colors.amber),
      SessionStatus.authenticated => ('Authenticated', Colors.green),
    };

    return _buildBadge(statusText, statusColor);
  }

  Widget _buildBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
