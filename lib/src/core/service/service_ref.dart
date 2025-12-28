import 'service.dart';

/// Reference passed to services for accessing dependencies.
///
/// [ServiceRef] provides:
/// - Access to other services via [get<T>()] (async, waits for initialization)
/// - Sync access via [getSync<T>()] when you know service is already initialized
/// - Factory instance creation via [create<T>()]
///
/// Example:
/// ```dart
/// class UserService extends Service {
///   late final AuthService _auth;
///
///   @override
///   Future<void> onInit() async {
///     _auth = await ref.get<AuthService>();
///   }
/// }
/// ```
abstract class ServiceRef {
  /// Get a singleton service by type and wait for initialization.
  ///
  /// This is the primary method for accessing services. It:
  /// - Creates the service lazily if not already instantiated
  /// - Waits for [Service.onInit()] to complete
  /// - Handles concurrent access safely (no race conditions)
  ///
  /// Use [name] to get a named instance registered with [registerNamed].
  ///
  /// Throws [ServiceNotFoundException] if the service is not registered.
  /// Throws [CircularDependencyException] if circular dependency detected.
  ///
  /// Example:
  /// ```dart
  /// @override
  /// Future<void> onInit() async {
  ///   final auth = await ref.get<AuthService>();
  ///   // auth is guaranteed to be fully initialized
  /// }
  /// ```
  Future<T> get<T extends Service>({String? name});

  /// Get a singleton service synchronously WITHOUT waiting for initialization.
  ///
  /// Use this only when:
  /// - You know the service is already initialized
  /// - You're in a synchronous context (constructor) and will use the service later
  /// - The service has no async initialization
  ///
  /// ⚠️ WARNING: If the service has async [onInit], it may not be complete
  /// when this returns. Prefer [get] unless you have a specific reason.
  ///
  /// Example:
  /// ```dart
  /// class MyService extends Service {
  ///   final LoggingService _logger; // No async init
  ///
  ///   MyService(ServiceRef ref) : _logger = ref.getSync<LoggingService>();
  /// }
  /// ```
  T getSync<T extends Service>({String? name});

  /// Check if a service is registered.
  bool has<T extends Service>({String? name});

  /// Create a NEW instance from a factory registration.
  ///
  /// Unlike [get], this always returns a fresh instance.
  /// Factory instances are NOT cached, NOT auto-initialized, and NOT auto-disposed.
  ///
  /// Use [name] to create from a named factory.
  ///
  /// Example:
  /// ```dart
  /// container.registerFactory<HttpRequest>((ref) => HttpRequest());
  ///
  /// final req1 = ref.create<HttpRequest>(); // New instance
  /// final req2 = ref.create<HttpRequest>(); // Different instance
  /// ```
  T create<T extends Service>({String? name});
}

/// Exception thrown when a requested service is not registered.
class ServiceNotFoundException implements Exception {
  final Type serviceType;
  final String? name;
  final String? message;

  const ServiceNotFoundException(this.serviceType, {this.name, this.message});

  @override
  String toString() {
    if (message != null) return 'ServiceNotFoundException: $message';
    final identifier =
        name != null ? '$serviceType($name)' : serviceType.toString();
    return 'ServiceNotFoundException: Service $identifier is not registered. '
        'Did you forget to call container.register<$serviceType>()?';
  }
}

/// Exception thrown when a circular dependency is detected.
class CircularDependencyException implements Exception {
  final List<Type> dependencyChain;

  const CircularDependencyException(this.dependencyChain);

  @override
  String toString() {
    final chain = dependencyChain.map((t) => t.toString()).join(' → ');
    return 'CircularDependencyException: Circular dependency detected: $chain';
  }
}

/// Exception thrown when trying to use a disposed service.
class ServiceDisposedException implements Exception {
  final Type serviceType;

  const ServiceDisposedException(this.serviceType);

  @override
  String toString() =>
      'ServiceDisposedException: Service $serviceType has been disposed.';
}
