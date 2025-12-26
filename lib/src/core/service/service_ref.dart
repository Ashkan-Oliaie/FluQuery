import '../common/common.dart';
import '../query/query.dart';
import '../persistence/persistence.dart';
import 'service.dart';

/// Reference passed to services for accessing dependencies and creating stores.
///
/// [ServiceRef] provides:
/// - Access to other services via [get<T>()] or [getAsync<T>()]
/// - Store creation via [createStore<TData, TError>()]
/// - Read-only access (no circular dependency with container)
///
/// Example:
/// ```dart
/// class UserService extends Service {
///   final AuthService _auth;
///   late final QueryStore<User?, Object> _userStore;
///
///   UserService(ServiceRef ref)
///     : _auth = ref.get<AuthService>() {
///     _userStore = ref.createStore(
///       queryKey: ['user', 'current'],
///       queryFn: _fetchUser,
///     );
///   }
/// }
/// ```
abstract class ServiceRef {
  /// Get a singleton service by type (synchronous).
  ///
  /// The service will be created lazily if not already instantiated.
  /// Note: If the service has async initialization, it may not be fully
  /// initialized when returned. Use [getAsync] if you need to wait.
  ///
  /// Use [name] to get a named instance registered with [registerNamed].
  ///
  /// Throws [ServiceNotFoundException] if the service is not registered.
  /// Throws [CircularDependencyException] if circular dependency detected.
  T get<T extends Service>({String? name});

  /// Get a service by type and wait for initialization (async-safe).
  ///
  /// This is the preferred method when:
  /// - Service has async initialization logic
  /// - Multiple callers might request the same service simultaneously
  /// - You need to ensure the service is fully ready before use
  ///
  /// Use [name] to get a named instance.
  ///
  /// Example:
  /// ```dart
  /// @override
  /// Future<void> onInit() async {
  ///   final auth = await ref.getAsync<AuthService>();
  ///   // auth is guaranteed to be fully initialized
  /// }
  /// ```
  Future<T> getAsync<T extends Service>({String? name});

  /// Check if a service is registered.
  bool has<T extends Service>();

  /// Create a NEW instance from a factory registration.
  ///
  /// Unlike [get], this always returns a fresh instance.
  /// Factory instances are NOT cached, NOT auto-initialized, and NOT auto-disposed.
  ///
  /// Use [name] to create from a named factory.
  T create<T extends Service>({String? name});

  /// Create a [QueryStore] owned by this service.
  ///
  /// The store will be automatically disposed when the service is disposed.
  QueryStore<TData, TError> createStore<TData, TError>({
    required QueryKey queryKey,
    required QueryFn<TData> queryFn,
    StaleTime? staleTime,
    int? retry,
    RetryDelayFn? retryDelay,
    Duration? refetchInterval,
    bool refetchOnWindowFocus = true,
    bool refetchOnReconnect = true,
    PersistOptions<TData>? persist,
  });

  /// Get the query cache for advanced use cases.
  QueryCache get queryCache;
}

/// Exception thrown when a requested service is not registered.
class ServiceNotFoundException implements Exception {
  final Type serviceType;
  final String? message;

  const ServiceNotFoundException(this.serviceType, {this.message});

  @override
  String toString() =>
      message ?? 'ServiceNotFoundException: Service of type $serviceType is not registered. '
          'Did you forget to call container.register<$serviceType>()?';
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

