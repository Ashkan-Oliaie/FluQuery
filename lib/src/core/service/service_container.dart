import 'dart:async';

import '../common/common.dart';
import '../query/query.dart';
import '../persistence/persistence.dart';
import 'service.dart';
import 'service_key.dart';
import 'service_ref.dart';
import 'internal/internal.dart';

/// Container for managing service registration, resolution, and lifecycle.
///
/// [ServiceContainer] provides:
/// - Service registration with factory functions
/// - Lazy initialization by default
/// - Automatic dependency resolution
/// - Circular dependency detection
/// - Lifecycle management (init, dispose, reset)
/// - QueryStore integration for stateful services
///
/// Example:
/// ```dart
/// final container = ServiceContainer(queryCache: queryCache);
///
/// container
///   ..register<LoggingService>((ref) => LoggingService())
///   ..register<ApiClient>((ref) => ApiClient(ref))
///   ..register<AuthService>((ref) => AuthService(ref));
///
/// await container.initialize();
///
/// final auth = await container.get<AuthService>();
/// ```
class ServiceContainer implements ServiceRef {
  // ============================================================
  // INTERNAL MODULES
  // ============================================================

  final ServiceRegistry _registry;
  final LifecycleManager _lifecycle;
  final StoreOwnership _storeOwnership;
  final ResolutionContext _resolution;

  // ============================================================
  // INSTANCE CACHES
  // ============================================================

  /// Instantiated singleton services
  final Map<Type, Service> _instances = {};

  /// Named singleton instances
  final Map<Type, Map<String, Service>> _namedInstances = {};

  // ============================================================
  // CONFIGURATION
  // ============================================================

  final QueryCache _queryCache;
  final DefaultQueryOptions _defaultOptions;
  final void Function<TData>(QueryKey, PersistOptions<TData>)?
      _persistRegistrar;
  final Future<void> Function<TData>(QueryKey, TData, DateTime?)?
      _persistCallback;
  final ServiceContainer? _parent;

  bool _isInitialized = false;

  ServiceContainer({
    required QueryCache queryCache,
    required DefaultQueryOptions defaultOptions,
    void Function<TData>(QueryKey, PersistOptions<TData>)? persistRegistrar,
    Future<void> Function<TData>(QueryKey, TData, DateTime?)? persistCallback,
    ServiceContainer? parent,
  })  : _queryCache = queryCache,
        _defaultOptions = defaultOptions,
        _persistRegistrar = persistRegistrar,
        _persistCallback = persistCallback,
        _parent = parent,
        _registry = ServiceRegistry(parent: parent?._registry),
        _lifecycle = LifecycleManager(),
        _storeOwnership = StoreOwnership(),
        _resolution = ResolutionContext();

  /// Whether the container has been initialized.
  bool get isInitialized => _isInitialized;

  // ============================================================
  // REGISTRATION (delegates to ServiceRegistry)
  // ============================================================

  /// Register a singleton service with a factory function.
  ///
  /// [factory] receives a [ServiceRef] for accessing dependencies.
  /// [lazy] controls whether the service is created on first access (default)
  /// or during [initialize()].
  ///
  /// Example:
  /// ```dart
  /// container.register<AuthService>((ref) => AuthService(ref));
  /// container.register<StartupService>((ref) => StartupService(ref), lazy: false);
  /// ```
  void register<T extends Service>(
    ServiceFactory<T> factory, {
    bool lazy = true,
  }) {
    _registry.registerSingleton<T>(factory, lazy: lazy);
  }

  /// Register a named singleton.
  ///
  /// Allows multiple instances of the same type with different names.
  /// Useful for multi-tenant apps, feature flags, or A/B testing.
  ///
  /// Example:
  /// ```dart
  /// container.registerNamed<ApiClient>('prod', (ref) => ApiClient(prodUrl));
  /// container.registerNamed<ApiClient>('staging', (ref) => ApiClient(stagingUrl));
  ///
  /// final prodApi = await container.get<ApiClient>(name: 'prod');
  /// final stagingApi = await container.get<ApiClient>(name: 'staging');
  /// ```
  void registerNamed<T extends Service>(
    String name,
    ServiceFactory<T> factory, {
    bool lazy = true,
  }) {
    _registry.registerNamedSingleton<T>(name, factory, lazy: lazy);
  }

  /// Register a factory that creates a NEW instance on every call.
  ///
  /// Unlike [register], factory instances are NOT cached.
  /// Use for request-scoped objects, form validators, etc.
  ///
  /// Factory instances are NOT auto-initialized or auto-disposed.
  ///
  /// Example:
  /// ```dart
  /// container.registerFactory<HttpRequest>((ref) => HttpRequest());
  ///
  /// final req1 = container.create<HttpRequest>(); // New instance
  /// final req2 = container.create<HttpRequest>(); // Different instance
  /// ```
  void registerFactory<T extends Service>(
    ServiceFactory<T> factory, {
    String? name,
  }) {
    if (name != null) {
      _registry.registerNamedFactory<T>(name, factory);
    } else {
      _registry.registerFactory<T>(factory);
    }
  }

  /// Unregister a service.
  ///
  /// If the service is instantiated, it will be disposed first.
  Future<void> unregister<T extends Service>({String? name}) async {
    if (name != null) {
      final instance = _namedInstances[T]?.remove(name);
      if (instance != null) {
        _storeOwnership.disposeStoresFor(T);
        await _lifecycle.dispose(instance);
      }
      _registry.unregisterNamedSingleton<T>(name);
    } else {
      final instance = _instances.remove(T);
      if (instance != null) {
        _storeOwnership.disposeStoresFor(T);
        await _lifecycle.dispose(instance);
      }
      _registry.unregisterSingleton<T>();
    }
  }

  // ============================================================
  // RESOLUTION (ServiceRef implementation)
  // ============================================================

  /// Get a singleton service and wait for initialization (async).
  ///
  /// This is the primary method for accessing services. It:
  /// - Creates the service lazily if not already instantiated
  /// - Waits for [Service.onInit()] to complete
  /// - Handles concurrent access safely
  @override
  Future<T> get<T extends Service>({String? name}) async {
    final service = _resolveSync<T>(name: name);

    // If container not initialized, service will be initialized during container.initialize()
    if (!_isInitialized) {
      return service;
    }

    // If already initialized, return immediately
    if (service.isInitialized) {
      return service;
    }

    // Initialize with lock (handles concurrent calls)
    final key = ServiceKey(T, name);
    await _lifecycle.initializeWithLock(key, service);
    return service;
  }

  /// Get a singleton service synchronously WITHOUT waiting for initialization.
  ///
  /// ⚠️ Use only when you know the service is already initialized
  /// or the service has no async initialization.
  @override
  T getSync<T extends Service>({String? name}) {
    final service = _resolveSync<T>(name: name);

    // Start initialization in background if container is initialized
    if (_isInitialized && !service.isInitialized) {
      final key = ServiceKey(T, name);
      _lifecycle.initializeWithLock(key, service).catchError((e, st) {
        FluQueryLogger.error('Async initialization failed for $T: $e', e, st);
      });
    }

    return service;
  }

  /// Internal synchronous resolution.
  T _resolveSync<T extends Service>({String? name}) {
    if (name != null) {
      return _resolveNamed<T>(name);
    }
    return _resolveUnnamed<T>();
  }

  T _resolveUnnamed<T extends Service>() {
    // Check if already instantiated
    final existing = _instances[T];
    if (existing != null) {
      if (existing.isDisposed) {
        _instances.remove(T);
        FluQueryLogger.debug('Recreating disposed service: $T');
      } else {
        return existing as T;
      }
    }

    // Check if registered
    final registration = _registry.getSingletonRegistration<T>();
    if (registration == null) {
      if (_parent != null) {
        return _parent._resolveUnnamed<T>();
      }
      throw ServiceNotFoundException(T);
    }

    // Create with circular dependency detection
    final isRoot = _resolution.enter(T);
    if (isRoot) {
      _storeOwnership.resolutionRoot = T;
    }

    try {
      final service = registration.factory(this);
      _instances[T] = service;
      return service;
    } finally {
      _resolution.exit(T, wasRoot: isRoot);
      if (isRoot) {
        _storeOwnership.resolutionRoot = null;
      }
    }
  }

  T _resolveNamed<T extends Service>(String name) {
    // Check if already instantiated
    final existing = _namedInstances[T]?[name];
    if (existing != null) {
      if (existing.isDisposed) {
        _namedInstances[T]?.remove(name);
        FluQueryLogger.debug('Recreating disposed named service: $T($name)');
      } else {
        return existing as T;
      }
    }

    // Check if registered
    final registration = _registry.getNamedSingletonRegistration<T>(name);
    if (registration == null) {
      if (_parent != null) {
        return _parent._resolveNamed<T>(name);
      }
      throw ServiceNotFoundException(T, name: name);
    }

    // Create the service
    final service = registration.factory(this);
    _namedInstances.putIfAbsent(T, () => {})[name] = service;

    // Start initialization if container is initialized
    if (_isInitialized && !service.isInitialized) {
      final key = ServiceKey(T, name);
      _lifecycle.initializeWithLock(key, service).catchError((e, st) {
        FluQueryLogger.error(
            'Async initialization failed for $T($name): $e', e, st);
      });
    }

    return service;
  }

  /// Create a NEW instance from a factory registration.
  @override
  T create<T extends Service>({String? name}) {
    ServiceRegistration<T>? registration;

    if (name != null) {
      registration = _registry.getNamedFactoryRegistration<T>(name);
    } else {
      registration = _registry.getFactoryRegistration<T>();
    }

    if (registration == null) {
      if (_parent != null) {
        return _parent.create<T>(name: name);
      }
      final identifier = name != null ? '$T($name)' : T.toString();
      throw ServiceNotFoundException(T,
          message: 'Factory $identifier is not registered.');
    }

    return registration.factory(this);
  }

  /// Check if a service is registered.
  @override
  bool has<T extends Service>({String? name}) {
    if (name != null) {
      return _registry.hasNamed<T>(name);
    }
    return _registry.has<T>();
  }

  /// Check if a service is instantiated.
  bool isInstantiated<T extends Service>({String? name}) {
    if (name != null) {
      return _namedInstances[T]?.containsKey(name) == true;
    }
    return _instances.containsKey(T);
  }

  // ============================================================
  // STORE CREATION (ServiceRef implementation)
  // ============================================================

  /// Create a QueryStore owned by the calling service.
  @override
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
  }) {
    final store = QueryStore<TData, TError>(
      queryKey: queryKey,
      queryFn: queryFn,
      cache: _queryCache,
      staleTime: staleTime ?? _defaultOptions.staleTime,
      retry: retry ?? _defaultOptions.retry,
      retryDelay: retryDelay ?? _defaultOptions.retryDelay,
      refetchInterval: refetchInterval,
      refetchOnWindowFocus: refetchOnWindowFocus,
      refetchOnReconnect: refetchOnReconnect,
      persist: persist,
      persistRegistrar: _persistRegistrar,
      persistCallback: _persistCallback,
    );

    // Determine owner from resolution context or lifecycle manager
    final ownerType =
        _storeOwnership.resolutionRoot ?? _lifecycle.currentlyInitializing;
    _storeOwnership.registerStore(ownerType, store, queryKey);

    return store;
  }

  // ============================================================
  // LIFECYCLE
  // ============================================================

  /// Initialize the container and all eager (non-lazy) services.
  ///
  /// Call this after all services are registered, typically during app startup.
  Future<void> initialize() async {
    if (_isInitialized) return;

    // Instantiate and init all eager services
    for (final entry in _registry.eagerRegistrations) {
      final service = _getByType(entry.key);
      await _lifecycle.initializeWithLock(ServiceKey(entry.key), service);
    }

    // Init any already-instantiated lazy services
    for (final entry in _instances.entries) {
      if (!entry.value.isInitialized) {
        await _lifecycle.initializeWithLock(ServiceKey(entry.key), entry.value);
      }
    }

    _isInitialized = true;
    FluQueryLogger.info(
        'ServiceContainer initialized with ${_instances.length} services');
  }

  /// Get a service by runtime type (for eager initialization).
  Service _getByType(Type type) {
    final existing = _instances[type];
    if (existing != null) return existing;

    final registration = _registry.getSingletonRegistrationByType(type);
    if (registration == null) {
      if (_parent != null) {
        return _parent._getByType(type);
      }
      throw ServiceNotFoundException(type);
    }

    final service = registration.factory(this);
    _instances[type] = service;
    return service;
  }

  /// Dispose a specific service.
  Future<void> dispose<T extends Service>({String? name}) async {
    if (name != null) {
      final instance = _namedInstances[T]?.remove(name);
      if (instance != null) {
        _storeOwnership.disposeStoresFor(T);
        await _lifecycle.dispose(instance);
      }
    } else {
      final instance = _instances.remove(T);
      if (instance != null) {
        _storeOwnership.disposeStoresFor(T);
        await _lifecycle.dispose(instance);
      }
    }
  }

  /// Dispose all services and clear the container.
  Future<void> disposeAll() async {
    // Wait for any pending initializations
    await _lifecycle.waitForPendingInitializations();

    // Dispose regular services in reverse order (LIFO)
    final services = _instances.values.toList().reversed;
    for (final service in services) {
      try {
        await service.dispose();
      } catch (e) {
        FluQueryLogger.error('Error disposing ${service.runtimeType}: $e');
      }
    }

    // Dispose named services
    for (final typeMap in _namedInstances.values) {
      for (final service in typeMap.values) {
        try {
          await service.dispose();
        } catch (e) {
          FluQueryLogger.error('Error disposing ${service.runtimeType}: $e');
        }
      }
    }

    // Dispose all stores
    _storeOwnership.disposeAll();

    // Clear everything
    _instances.clear();
    _namedInstances.clear();
    _lifecycle.clear();
    _isInitialized = false;

    FluQueryLogger.info('ServiceContainer disposed');
  }

  /// Reset a specific service.
  Future<void> reset<T extends Service>(
      {String? name, bool recreate = false}) async {
    final Service? instance;
    if (name != null) {
      instance = _namedInstances[T]?[name];
    } else {
      instance = _instances[T];
    }

    if (instance == null) return;

    if (recreate) {
      _storeOwnership.disposeStoresFor(T);
      await _lifecycle.dispose(instance);
      if (name != null) {
        _namedInstances[T]?.remove(name);
      } else {
        _instances.remove(T);
      }
      // Will be lazily recreated on next access
    } else {
      await _lifecycle.reset(instance);
    }
  }

  /// Reset all services.
  Future<void> resetAll({bool recreate = false}) async {
    if (recreate) {
      await disposeAll();
    } else {
      for (final service in _instances.values) {
        try {
          await service.reset();
        } catch (e) {
          FluQueryLogger.error('Error resetting ${service.runtimeType}: $e');
        }
      }
      for (final typeMap in _namedInstances.values) {
        for (final service in typeMap.values) {
          try {
            await service.reset();
          } catch (e) {
            FluQueryLogger.error('Error resetting ${service.runtimeType}: $e');
          }
        }
      }
      FluQueryLogger.info('All services reset');
    }
  }

  // ============================================================
  // SCOPING
  // ============================================================

  /// Create a scoped child container.
  ///
  /// Scoped containers inherit registrations from parent but can override them.
  ServiceContainer createScope() {
    return ServiceContainer(
      queryCache: _queryCache,
      defaultOptions: _defaultOptions,
      persistRegistrar: _persistRegistrar,
      persistCallback: _persistCallback,
      parent: this,
    );
  }
}
