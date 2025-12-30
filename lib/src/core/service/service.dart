import 'dart:async';

import 'service_ref.dart';

/// Base class for all services managed by [ServiceContainer].
///
/// Services support:
/// - Dependency access via [ref]
/// - Async initialization via [onInit]
/// - Cleanup via [onDispose]
///
/// For services with reactive state, use [StatefulService] instead.
///
/// ```dart
/// class AuthService extends Service {
///   late final ApiClient _api;
///
///   @override
///   Future<void> onInit() async {
///     _api = await ref.get<ApiClient>();
///     await _loadTokenFromStorage();
///   }
/// }
/// ```
abstract class Service {
  bool _isInitialized = false;
  bool _isDisposed = false;
  ServiceRef? _ref;

  bool get isInitialized => _isInitialized;
  bool get isDisposed => _isDisposed;

  /// Access other services from the container.
  ServiceRef get ref {
    if (_ref == null) {
      throw StateError(
        'Service ref accessed before initialization. '
        'This service was not created by ServiceContainer.',
      );
    }
    return _ref!;
  }

  /// Called after creation. Override for async initialization.
  Future<void> onInit() async {}

  /// Called on disposal. Override to clean up resources.
  Future<void> onDispose() async {}

  /// Called on reset. Override to reset state without recreating.
  Future<void> onReset() async {}

  /// Internal: Set by container after creation.
  void setRef(ServiceRef ref) => _ref = ref;

  Future<void> initialize() async {
    if (_isInitialized) return;
    await onInit();
    _isInitialized = true;
  }

  Future<void> dispose() async {
    if (_isDisposed) return;
    await onDispose();
    _isDisposed = true;
    _isInitialized = false;
  }

  Future<void> reset() async => onReset();
}

/// Factory function type for creating services.
typedef ServiceFactory<T extends Service> = T Function(ServiceRef ref);

/// Registration info for a service.
class ServiceRegistration<T extends Service> {
  final ServiceFactory<T> factory;
  final bool lazy;

  const ServiceRegistration({required this.factory, this.lazy = true});
}
