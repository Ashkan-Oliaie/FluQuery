import 'dart:async';

import '../common/common.dart';
import '../query/query.dart';
import '../persistence/persistence.dart';
import 'service.dart';
import 'service_ref.dart';

/// A simple async lock that ensures only one execution at a time.
/// Subsequent calls wait for the first to complete.
class _AsyncLock {
  Completer<void>? _completer;
  
  /// Execute [action] with mutual exclusion.
  /// If already running, waits for completion without re-executing.
  Future<void> synchronized(Future<void> Function() action) async {
    // If already running, wait for completion
    if (_completer != null) {
      await _completer!.future;
      return;
    }
    
    // Start execution
    _completer = Completer<void>();
    
    try {
      await action();
      _completer!.complete();
    } catch (e, st) {
      _completer!.completeError(e, st);
      rethrow;
    } finally {
      _completer = null;
    }
  }
  
  /// Whether currently executing.
  bool get isRunning => _completer != null;
  
  /// Wait for current execution to complete (if any).
  Future<void> waitIfRunning() async {
    if (_completer != null) {
      await _completer!.future.catchError((_) {});
    }
  }
}

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
/// final container = ServiceContainer(queryCache: queryCache)
///   ..register<LoggingService>((ref) => LoggingService())
///   ..register<ApiClient>((ref) => ApiClient(ref))
///   ..register<AuthService>((ref) => AuthService(ref));
///
/// await container.initialize(); // Init all eager services
///
/// final auth = container.get<AuthService>(); // Lazy init
/// ```
class ServiceContainer implements ServiceRef {
  final QueryCache _queryCache;
  final DefaultQueryOptions _defaultOptions;

  /// Persistence callbacks (injected from QueryClient)
  final void Function<TData>(QueryKey, PersistOptions<TData>)? _persistRegistrar;
  final Future<void> Function<TData>(QueryKey, TData, DateTime?)? _persistCallback;

  /// Registered service factories (singletons)
  final Map<Type, ServiceRegistration> _registrations = {};

  /// Named service registrations: type -> name -> registration
  final Map<Type, Map<String, ServiceRegistration>> _namedRegistrations = {};

  /// Factory registrations (new instance every call)
  final Map<Type, ServiceRegistration> _factories = {};

  /// Named factory registrations
  final Map<Type, Map<String, ServiceRegistration>> _namedFactories = {};

  /// Instantiated services (singletons)
  final Map<Type, Service> _instances = {};

  /// Named service instances
  final Map<Type, Map<String, Service>> _namedInstances = {};

  /// Services currently being resolved (for circular dependency detection)
  final Set<Type> _resolving = {};

  /// The root service type being resolved (for store ownership)
  /// This is the FIRST service in the resolution chain, not the current one.
  Type? _resolutionRoot;

  /// Async locks for initialization (one per service key, prevents race conditions)
  /// Key can be Type (for regular services) or String (for named services: 'Type#name')
  final Map<Object, _AsyncLock> _initLocks = {};

  /// Currently initializing service type (for store ownership tracking)
  Type? _currentlyInitializing;

  /// Stores created by services (for cleanup)
  final Map<Type, List<QueryStore>> _serviceStores = {};

  /// Whether the container has been initialized
  bool _isInitialized = false;

  /// Parent container for scoping (optional)
  final ServiceContainer? _parent;

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
        _parent = parent;

  /// Whether the container has been initialized
  bool get isInitialized => _isInitialized;

  /// Get the query cache
  @override
  QueryCache get queryCache => _queryCache;

  // ============================================================
  // REGISTRATION
  // ============================================================

  /// Register a service with a factory function.
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
    if (_registrations.containsKey(T)) {
      FluQueryLogger.warn('Service $T is already registered. Overwriting.');
    }
    _registrations[T] = ServiceRegistration<T>(factory: factory, lazy: lazy);
  }

  /// Register a factory that creates a NEW instance on every call.
  ///
  /// Unlike [register], factory instances are NOT cached and each call
  /// to [create] returns a fresh instance. Use for stateless services,
  /// request-scoped objects, or anything that shouldn't be shared.
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
      _namedFactories.putIfAbsent(T, () => {})[name] =
          ServiceRegistration<T>(factory: factory, lazy: true);
      FluQueryLogger.debug('Registered named factory: $T($name)');
    } else {
      if (_factories.containsKey(T)) {
        FluQueryLogger.warn('Factory $T is already registered. Overwriting.');
      }
      _factories[T] = ServiceRegistration<T>(factory: factory, lazy: true);
    }
  }

  /// Register a named singleton.
  ///
  /// Allows multiple instances of the same type with different names.
  /// Useful for multi-tenant apps, feature flags, or A/B testing.
  ///
  /// Example:
  /// ```dart
  /// container.register<ApiClient>(
  ///   (ref) => ApiClient(baseUrl: 'api.tenant-a.com'),
  ///   name: 'tenantA',
  /// );
  /// container.register<ApiClient>(
  ///   (ref) => ApiClient(baseUrl: 'api.tenant-b.com'),
  ///   name: 'tenantB',
  /// );
  ///
  /// final a = container.get<ApiClient>(name: 'tenantA');
  /// final b = container.get<ApiClient>(name: 'tenantB');
  /// ```
  void registerNamed<T extends Service>(
    String name,
    ServiceFactory<T> factory, {
    bool lazy = true,
  }) {
    _namedRegistrations.putIfAbsent(T, () => {})[name] =
        ServiceRegistration<T>(factory: factory, lazy: lazy);
    FluQueryLogger.debug('Registered named service: $T($name)');
  }

  /// Unregister a service.
  ///
  /// If the service is instantiated, it will be disposed first.
  Future<void> unregister<T extends Service>({String? name}) async {
    if (name != null) {
      final instance = _namedInstances[T]?.remove(name);
      if (instance != null) {
        await _disposeServiceByType(T, instance);
      }
      _namedRegistrations[T]?.remove(name);
    } else {
      final instance = _instances.remove(T);
      if (instance != null) {
        await _disposeService<T>(instance);
      }
      _registrations.remove(T);
    }
  }

  // ============================================================
  // RESOLUTION
  // ============================================================

  /// Get a singleton service by type (synchronous).
  ///
  /// Creates the service lazily if not already instantiated.
  /// For services with async initialization, prefer [getAsync] to ensure
  /// initialization completes before use.
  ///
  /// Use [name] to get a named instance registered with [registerNamed].
  ///
  /// Throws [ServiceNotFoundException] if not registered.
  /// Throws [CircularDependencyException] if circular dependency detected.
  @override
  T get<T extends Service>({String? name}) {
    return _resolve<T>(name: name);
  }

  /// Get a service by type and wait for initialization (async-safe).
  ///
  /// This is the preferred method when:
  /// - Service has async initialization logic
  /// - Multiple widgets might request the same service simultaneously
  /// - You need to ensure the service is fully ready before use
  ///
  /// Use [name] to get a named instance.
  ///
  /// Example:
  /// ```dart
  /// final auth = await container.getAsync<AuthService>();
  /// // auth.onInit() is guaranteed to have completed
  /// ```
  Future<T> getAsync<T extends Service>({String? name}) async {
    final service = _resolve<T>(name: name);

    // If container not initialized yet, service will be initialized during container.initialize()
    if (!_isInitialized) {
      return service;
    }

    // If already initialized, return immediately
    if (service.isInitialized) {
      return service;
    }

    // Initialize with lock (handles concurrent calls)
    final lockKey = name != null ? '$T#$name' : T;
    await _initializeServiceWithLock(lockKey, service);
    return service;
  }

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
  /// final req1 = container.create<HttpRequest>(); // New instance
  /// final req2 = container.create<HttpRequest>(); // Different instance
  /// assert(!identical(req1, req2));
  /// ```
  T create<T extends Service>({String? name}) {
    ServiceRegistration? registration;

    if (name != null) {
      registration = _namedFactories[T]?[name];
    } else {
      registration = _factories[T];
    }

    if (registration == null) {
      // Try parent container
      if (_parent != null) {
        return _parent.create<T>(name: name);
      }
      final identifier = name != null ? '$T($name)' : T.toString();
      throw ServiceNotFoundException(T, message: 'Factory $identifier is not registered.');
    }

    final factory = registration.factory as ServiceFactory<T>;
    return factory(this);
  }

  /// Internal resolution logic for singletons.
  T _resolve<T extends Service>({String? name}) {
    // Handle named services
    if (name != null) {
      return _resolveNamed<T>(name);
    }

    // Check if already instantiated
    final existing = _instances[T];
    if (existing != null) {
      if (existing.isDisposed) {
        // Remove disposed instance and allow recreation
        _instances.remove(T);
        FluQueryLogger.debug('Recreating disposed service: $T');
      } else {
        return existing as T;
      }
    }

    // Check if registered
    final registration = _registrations[T];
    if (registration == null) {
      // Try parent container
      if (_parent != null) {
        return _parent.get<T>();
      }
      throw ServiceNotFoundException(T);
    }

    // Check for circular dependency
    if (_resolving.contains(T)) {
      throw CircularDependencyException([..._resolving, T].toList());
    }

    // Track resolution root (first service in chain) for store ownership
    final isRoot = _resolving.isEmpty;
    if (isRoot) {
      _resolutionRoot = T;
    }

    // Create the service
    _resolving.add(T);
    try {
      final factory = registration.factory as ServiceFactory<T>;
      final service = factory(this);
      _instances[T] = service;

      // Start initialization if container is already initialized
      // Use fire-and-forget for sync get(), callers should use getAsync() if they need to wait
      if (_isInitialized && !service.isInitialized) {
        _initializeServiceWithLock(T, service).catchError((e, st) {
          FluQueryLogger.error('Async initialization failed for $T: $e', e, st);
        });
      }

      return service;
    } finally {
      _resolving.remove(T);
      if (isRoot) {
        _resolutionRoot = null;
      }
    }
  }

  /// Resolve a named service.
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
    final registration = _namedRegistrations[T]?[name];
    if (registration == null) {
      // Try parent
      if (_parent != null) {
        return _parent.get<T>(name: name);
      }
      throw ServiceNotFoundException(T, message: 'Named service $T($name) is not registered.');
    }

    // Create the service
    final factory = registration.factory as ServiceFactory<T>;
    final service = factory(this);
    _namedInstances.putIfAbsent(T, () => {})[name] = service;

    // Start initialization if container is initialized
    if (_isInitialized && !service.isInitialized) {
      final lockKey = '$T#$name';
      _initializeServiceWithLock(lockKey, service).catchError((e, st) {
        FluQueryLogger.error('Async initialization failed for $T($name): $e', e, st);
      });
    }

    return service;
  }

  /// Initialize a service with a lock to prevent double initialization.
  /// [key] can be a Type or a String (for named services: 'Type#name').
  Future<void> _initializeServiceWithLock(Object key, Service service) async {
    if (service.isInitialized) return;
    
    // Get or create lock for this service key
    final lock = _initLocks.putIfAbsent(key, () => _AsyncLock());
    
    await lock.synchronized(() => _initializeService(service));
  }

  /// Check if a service is registered.
  @override
  bool has<T extends Service>() {
    return _registrations.containsKey(T) ||
        (_parent?.has<T>() ?? false);
  }

  /// Check if a service is instantiated.
  bool isInstantiated<T extends Service>() {
    return _instances.containsKey(T);
  }

  // ============================================================
  // STORE CREATION
  // ============================================================

  /// Create a QueryStore owned by the calling service.
  /// 
  /// The store will be automatically disposed when its owning service is disposed.
  /// Ownership is determined by:
  /// 1. The service currently being resolved (constructor-time creation)
  /// 2. The service currently being initialized (onInit-time creation)
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

    // Track store for cleanup - determine owner from:
    // 1. Resolution root (the service that started the resolution chain)
    // 2. Service being initialized (onInit) - _currentlyInitializing
    // We use _resolutionRoot instead of _resolving.last to correctly attribute
    // stores to the service that actually creates them, not nested dependencies.
    final ownerType = _resolutionRoot ?? _currentlyInitializing;
    
    if (ownerType != null) {
      _serviceStores.putIfAbsent(ownerType, () => []).add(store);
      FluQueryLogger.debug('Store $queryKey assigned to service $ownerType');
    } else {
      FluQueryLogger.warn(
        'Store $queryKey created outside service context - will not be auto-disposed'
      );
    }

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
    for (final entry in _registrations.entries) {
      if (!entry.value.lazy) {
        final service = _getByRuntimeType(entry.key);
        await _initializeServiceWithLock(entry.key, service);
      }
    }

    // Init any already-instantiated lazy services
    for (final entry in _instances.entries) {
      if (!entry.value.isInitialized) {
        await _initializeServiceWithLock(entry.key, entry.value);
      }
    }

    _isInitialized = true;
    FluQueryLogger.info('ServiceContainer initialized with ${_instances.length} services');
  }

  /// Get a service by runtime type (internal use).
  /// Used during eager initialization.
  Service _getByRuntimeType(Type type) {
    final existing = _instances[type];
    if (existing != null) return existing;

    final registration = _registrations[type];
    if (registration == null) {
      if (_parent != null) {
        return _parent._getByRuntimeType(type);
      }
      throw ServiceNotFoundException(type);
    }

    _resolving.add(type);
    try {
      final service = registration.factory(this);
      _instances[type] = service;
      return service;
    } finally {
      _resolving.remove(type);
    }
  }

  Future<void> _initializeService(Service service) async {
    if (service.isInitialized) return;
    
    // Track which service is initializing (for store ownership)
    final previouslyInitializing = _currentlyInitializing;
    _currentlyInitializing = service.runtimeType;
    
    try {
      await service.initialize();
      FluQueryLogger.debug('Initialized service: ${service.runtimeType}');
    } catch (e, stackTrace) {
      FluQueryLogger.error(
        'Failed to initialize service ${service.runtimeType}: $e',
        e,
        stackTrace,
      );
      rethrow;
    } finally {
      _currentlyInitializing = previouslyInitializing;
    }
  }

  /// Dispose a specific service.
  Future<void> dispose<T extends Service>() async {
    final instance = _instances.remove(T);
    if (instance != null) {
      await _disposeService<T>(instance);
    }
  }

  Future<void> _disposeService<T>(Service service) async {
    await _disposeServiceByType(T, service);
  }

  Future<void> _disposeServiceByType(Type type, Service service) async {
    // Dispose stores owned by this service
    final stores = _serviceStores.remove(type);
    if (stores != null) {
      for (final store in stores) {
        store.dispose();
      }
    }

    await service.dispose();
    FluQueryLogger.debug('Disposed service: $type');
  }

  /// Dispose all services and clear the container.
  Future<void> disposeAll() async {
    // Wait for any pending initializations to complete first
    final runningLocks = _initLocks.values.where((l) => l.isRunning).toList();
    if (runningLocks.isNotEmpty) {
      FluQueryLogger.debug('Waiting for ${runningLocks.length} pending initializations before dispose');
      await Future.wait(runningLocks.map((l) => l.waitIfRunning()));
    }

    // Dispose regular services in reverse order of instantiation (LIFO)
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
    for (final stores in _serviceStores.values) {
      for (final store in stores) {
        store.dispose();
      }
    }

    _instances.clear();
    _namedInstances.clear();
    _serviceStores.clear();
    _initLocks.clear();
    _isInitialized = false;
    FluQueryLogger.info('ServiceContainer disposed');
  }

  /// Reset a specific service.
  ///
  /// Calls [Service.onReset()] and optionally recreates the service.
  Future<void> reset<T extends Service>({bool recreate = false}) async {
    final instance = _instances[T];
    if (instance == null) return;

    if (recreate) {
      await _disposeService<T>(instance);
      _instances.remove(T);
      // Will be lazily recreated on next access
    } else {
      await instance.reset();
      FluQueryLogger.debug('Reset service: $T');
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
      FluQueryLogger.info('All services reset');
    }
  }

  // ============================================================
  // SCOPING
  // ============================================================

  /// Create a scoped child container.
  ///
  /// Scoped containers inherit registrations from parent but can override them.
  /// Useful for multi-tenant apps or test isolation.
  ///
  /// Example:
  /// ```dart
  /// final scopedContainer = container.createScope();
  /// scopedContainer.register<TenantService>((ref) => TenantService(tenantId));
  /// ```
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

