import 'dart:async';

import 'service_ref.dart';

/// Base class for all services in the application.
///
/// Services are singletons managed by [ServiceContainer] that:
/// - Can depend on other services via [ServiceRef]
/// - Support async initialization via [onInit]
/// - Support cleanup via [onDispose]
/// - Can own [QueryStore] instances for stateful data
///
/// Example:
/// ```dart
/// class AuthService extends Service {
///   final ApiClient _api;
///   final LoggingService _logger;
///
///   AuthService(ServiceRef ref)
///     : _api = ref.get<ApiClient>(),
///       _logger = ref.get<LoggingService>();
///
///   @override
///   Future<void> onInit() async {
///     await _loadTokenFromStorage();
///   }
///
///   @override
///   Future<void> onDispose() async {
///     await _clearSession();
///   }
/// }
/// ```
abstract class Service {
  bool _isInitialized = false;
  bool _isDisposed = false;

  /// Whether this service has been initialized.
  bool get isInitialized => _isInitialized;

  /// Whether this service has been disposed.
  bool get isDisposed => _isDisposed;

  /// Called after the service is created and all dependencies are resolved.
  ///
  /// Override this for async initialization like loading from storage.
  /// This is called automatically by the container.
  Future<void> onInit() async {}

  /// Called when the service is being disposed.
  ///
  /// Override this to clean up resources, cancel subscriptions, etc.
  Future<void> onDispose() async {}

  /// Called when the service is being reset.
  ///
  /// Override this to reset service state (e.g., on logout).
  /// Default implementation disposes and reinitializes.
  Future<void> onReset() async {}

  /// Internal method called by container to initialize.
  Future<void> initialize() async {
    if (_isInitialized) return;
    await onInit();
    _isInitialized = true;
  }

  /// Internal method called by container to dispose.
  Future<void> dispose() async {
    if (_isDisposed) return;
    await onDispose();
    _isDisposed = true;
    _isInitialized = false;
  }

  /// Internal method called by container to reset.
  Future<void> reset() async {
    await onReset();
  }
}

/// Factory function type for creating services.
typedef ServiceFactory<T extends Service> = T Function(ServiceRef ref);

/// Registration info for a service.
class ServiceRegistration<T extends Service> {
  final ServiceFactory<T> factory;
  final bool lazy;

  const ServiceRegistration({
    required this.factory,
    this.lazy = true,
  });
}


