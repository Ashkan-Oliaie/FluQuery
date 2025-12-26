import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:fluquery/fluquery.dart';

import '../../shared/shared.dart';
import '../widgets/code_block.dart';

/// Demonstrates factory registrations - new instance on every call.
///
/// Real-world use cases:
/// - HTTP request objects (each request is unique)
/// - Form validators (per-form instance)
/// - Logger instances with different contexts
/// - Transaction handlers
/// - File upload handlers
class FactoryScenario extends HookWidget {
  const FactoryScenario({super.key});

  @override
  Widget build(BuildContext context) {
    final client = QueryClientProvider.of(context);
    final scope = useMemoized(() {
      final s = client.services!.createScope();
      // Register factories - new instance every time
      s.registerFactory<RequestService>((ref) => RequestService());
      s.registerFactory<FormValidator>((ref) => FormValidator());
      return s;
    }, [client]);

    useEffect(() {
      scope.initialize();
      return () => scope.disposeAll();
    }, [scope]);

    final requests = useState<List<RequestService>>([]);
    final validators = useState<List<FormValidator>>([]);

    void createRequest() {
      final request = scope.create<RequestService>();
      requests.value = [...requests.value, request];
    }

    void createValidator() {
      final validator = scope.create<FormValidator>();
      validators.value = [...validators.value, validator];
    }

    void clearAll() {
      requests.value = [];
      validators.value = [];
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
                // Request factory demo
                Expanded(
                  child: _FactoryDemo<RequestService>(
                    title: 'Request Factory',
                    subtitle: 'Each API call gets its own request object',
                    icon: Icons.http_rounded,
                    color: const Color(0xFF3B82F6),
                    instances: requests.value,
                    onCreate: createRequest,
                    renderInstance: (instance) =>
                        _RequestCard(request: instance),
                  ),
                ),
                const SizedBox(width: 16),
                // Validator factory demo
                Expanded(
                  child: _FactoryDemo<FormValidator>(
                    title: 'Validator Factory',
                    subtitle: 'Each form gets its own validator',
                    icon: Icons.verified_user_rounded,
                    color: const Color(0xFFF59E0B),
                    instances: validators.value,
                    onCreate: createValidator,
                    renderInstance: (instance) =>
                        _ValidatorCard(validator: instance),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              OutlinedButton.icon(
                onPressed: clearAll,
                icon: const Icon(Icons.clear_all_rounded),
                label: const Text('Clear All'),
              ),
              const Spacer(),
              _buildComparisonInfo(context, requests.value, validators.value),
            ],
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
          'Factory Pattern',
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Unlike singletons, factories create a NEW instance on every call to create().',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
          ),
        ),
      ],
    );
  }

  Widget _buildComparisonInfo(
    BuildContext context,
    List<RequestService> requests,
    List<FormValidator> validators,
  ) {
    final theme = Theme.of(context);

    // Check if any two instances are identical
    bool allUnique = true;
    for (int i = 0; i < requests.length && allUnique; i++) {
      for (int j = i + 1; j < requests.length && allUnique; j++) {
        if (identical(requests[i], requests[j])) {
          allUnique = false;
        }
      }
    }
    for (int i = 0; i < validators.length && allUnique; i++) {
      for (int j = i + 1; j < validators.length && allUnique; j++) {
        if (identical(validators[i], validators[j])) {
          allUnique = false;
        }
      }
    }

    final total = requests.length + validators.length;
    if (total == 0) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: allUnique
            ? Colors.green.withValues(alpha: 0.1)
            : Colors.red.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: allUnique
              ? Colors.green.withValues(alpha: 0.3)
              : Colors.red.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            allUnique ? Icons.check_circle_rounded : Icons.error_rounded,
            size: 16,
            color: allUnique ? Colors.green : Colors.red,
          ),
          const SizedBox(width: 8),
          Text(
            '$total instances • All unique: $allUnique',
            style: theme.textTheme.labelMedium?.copyWith(
              color: allUnique ? Colors.green : Colors.red,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _FactoryDemo<T> extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final List<T> instances;
  final VoidCallback onCreate;
  final Widget Function(T) renderInstance;

  const _FactoryDemo({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.instances,
    required this.onCreate,
    required this.renderInstance,
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
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: color, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        subtitle,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onSurface
                              .withValues(alpha: 0.5),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: onCreate,
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('Create Instance'),
                style: FilledButton.styleFrom(backgroundColor: color),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Instances (${instances.length})',
              style: theme.textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: instances.isEmpty
                  ? Center(
                      child: Text(
                        'No instances created yet',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface
                              .withValues(alpha: 0.4),
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    )
                  : ListView.separated(
                      itemCount: instances.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, index) =>
                          renderInstance(instances[index]),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RequestCard extends StatelessWidget {
  final RequestService request;

  const _RequestCard({required this.request});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.05)
            : Colors.grey.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.1)
              : Colors.grey.withValues(alpha: 0.1),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: Colors.green,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Request #${request.id}',
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  'Hash: ${request.hashCode}',
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontFamily: 'monospace',
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                  ),
                ),
              ],
            ),
          ),
          Text(
            request.createdAt,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
            ),
          ),
        ],
      ),
    );
  }
}

class _ValidatorCard extends StatelessWidget {
  final FormValidator validator;

  const _ValidatorCard({required this.validator});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.05)
            : Colors.grey.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.1)
              : Colors.grey.withValues(alpha: 0.1),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: Colors.amber,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Validator #${validator.id}',
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  'Rules: ${validator.rulesCount}',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                  ),
                ),
              ],
            ),
          ),
          Text(
            'Hash: ${validator.hashCode.toRadixString(16).toUpperCase()}',
            style: theme.textTheme.labelSmall?.copyWith(
              fontFamily: 'monospace',
              color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
            ),
          ),
        ],
      ),
    );
  }
}

class _CodeExample extends StatelessWidget {
  const _CodeExample();

  @override
  Widget build(BuildContext context) {
    return const CodeBlock(
      title: 'Singleton vs Factory Pattern',
      code: '''// SINGLETON - same instance every time
container.register<AuthService>((ref) => AuthService(ref));

final auth1 = container.get<AuthService>();
final auth2 = container.get<AuthService>();
assert(identical(auth1, auth2)); // Same instance


// FACTORY - NEW instance every time  
container.registerFactory<HttpRequest>((ref) => HttpRequest());

final req1 = container.create<HttpRequest>();
final req2 = container.create<HttpRequest>();
assert(!identical(req1, req2)); // Different instances''',
    );
  }
}

/// Example request service - each instance has unique ID
class RequestService extends Service {
  static int _counter = 0;
  final int id;
  final String createdAt;

  RequestService()
      : id = ++_counter,
        createdAt = _formatTime(DateTime.now());

  static String _formatTime(DateTime time) {
    return '${time.hour.toString().padLeft(2, '0')}:'
        '${time.minute.toString().padLeft(2, '0')}:'
        '${time.second.toString().padLeft(2, '0')}';
  }
}

/// Example form validator - each form gets its own instance
class FormValidator extends Service {
  static int _counter = 0;
  final int id;
  final int rulesCount;

  FormValidator()
      : id = ++_counter,
        rulesCount = 5 + (_counter % 5);

  bool validate(Map<String, dynamic> data) {
    // Validation logic
    return true;
  }
}
