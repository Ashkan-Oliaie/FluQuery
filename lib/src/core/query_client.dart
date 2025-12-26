import 'common/common.dart';
import 'query/query.dart';
import 'mutation/mutation.dart';
import 'persistence/persistence.dart';
import 'store/store.dart';
import 'service/services.dart';
import 'query_client_config.dart';

// Re-export config classes for backward compatibility
export 'query_client_config.dart';

/// The main client for managing queries and mutations.
///
/// This is the central coordinator that orchestrates:
/// - Query caching and fetching
/// - Mutation management
/// - Persistence (via [PersistenceManager])
/// - QueryStores (via [StoreManager])
/// - Services (via [ServiceContainer])
/// - Network state handling
class QueryClient {
  final QueryCache _queryCache;
  final MutationCache _mutationCache;
  final QueryClientConfig _config;
  final Map<String, InfiniteQuery> _infiniteQueries = {};

  // Managers
  PersistenceManager? _persistenceManager;
  late final StoreManager _storeManager;
  ServiceContainer? _services;

  // Network state
  bool _isOnline = true;
  bool _isFocused = true;
  bool _isMounted = false;

  QueryClient({
    QueryCache? queryCache,
    MutationCache? mutationCache,
    QueryClientConfig? config,
    Persister? persister,
  })  : _queryCache = queryCache ?? QueryCache(),
        _mutationCache = mutationCache ?? MutationCache(),
        _config = config ?? QueryClientConfig() {
    FluQueryLogger.level = _config.logLevel;

    // Initialize persistence manager if persister is provided
    if (persister != null) {
      _persistenceManager = PersistenceManager(
        persister: persister,
        queryCache: _queryCache,
      );
      _queryCache.onDataSuccess = _persistenceManager!.onQueryDataSuccess;
    }

    // Initialize store manager
    _storeManager = StoreManager(
      queryCache: _queryCache,
      defaultOptions: _config.defaultOptions,
      persistRegistrar:
          _persistenceManager != null ? registerPersistOptions : null,
      persistCallback: _persistenceManager != null ? persistQuery : null,
    );
  }

  // ============================================================
  // GETTERS
  // ============================================================

  /// Whether the cache has been hydrated from persistence
  bool get isHydrated => _persistenceManager?.isHydrated ?? false;

  /// The persister instance (if configured)
  Persister? get persister => _persistenceManager?.persister;

  /// Query cache
  QueryCache get queryCache => _queryCache;

  /// Mutation cache
  MutationCache get mutationCache => _mutationCache;

  /// Default options
  DefaultQueryOptions get defaultOptions => _config.defaultOptions;

  /// Whether the client is mounted
  bool get isMounted => _isMounted;

  /// Whether the device is online
  bool get isOnline => _isOnline;

  /// Whether the app is focused
  bool get isFocused => _isFocused;

  /// Get all active stores
  Iterable<QueryStore> get stores => _storeManager.stores;

  /// Get the service container (if configured)
  ServiceContainer? get services => _services;

  // ============================================================
  // LIFECYCLE
  // ============================================================

  /// Mount the client
  void mount() {
    _isMounted = true;
    FluQueryLogger.debug('QueryClient mounted');
  }

  /// Unmount the client
  void unmount() {
    _isMounted = false;
    FluQueryLogger.debug('QueryClient unmounted');
  }

  // ============================================================
  // SERVICES
  // ============================================================

  /// Initialize the service container.
  ///
  /// Call this to enable service management in the client.
  /// Pass a configuration callback to register services.
  ///
  /// Example:
  /// ```dart
  /// await queryClient.initServices((container) {
  ///   container.register<LoggingService>((ref) => LoggingService());
  ///   container.register<ApiClient>((ref) => ApiClient(ref));
  ///   container.register<AuthService>((ref) => AuthService(ref));
  /// });
  /// ```
  Future<void> initServices(
    void Function(ServiceContainer container) configure,
  ) async {
    _services = ServiceContainer(
      queryCache: _queryCache,
      defaultOptions: _config.defaultOptions,
      persistRegistrar:
          _persistenceManager != null ? registerPersistOptions : null,
      persistCallback: _persistenceManager != null ? persistQuery : null,
    );

    configure(_services!);
    await _services!.initialize();
  }

  /// Get a service by type (synchronous).
  ///
  /// Shorthand for `client.services!.getSync<T>()`.
  ///
  /// ⚠️ If the service has async initialization, use [getServiceAsync] instead
  /// to ensure [Service.onInit()] has completed.
  ///
  /// Throws if services are not initialized.
  T getService<T extends Service>({String? name}) {
    if (_services == null) {
      throw StateError(
        'getService<$T>() called but services are not initialized. '
        'Call initServices() first.',
      );
    }
    return _services!.getSync<T>(name: name);
  }

  /// Get a service by type and wait for initialization (async).
  ///
  /// Shorthand for `await client.services!.get<T>()`.
  ///
  /// Preferred method when the service has async initialization.
  ///
  /// Throws if services are not initialized.
  Future<T> getServiceAsync<T extends Service>({String? name}) async {
    if (_services == null) {
      throw StateError(
        'getServiceAsync<$T>() called but services are not initialized. '
        'Call initServices() first.',
      );
    }
    return _services!.get<T>(name: name);
  }

  /// Reset a specific service.
  Future<void> resetService<T extends Service>({bool recreate = false}) async {
    await _services?.reset<T>(recreate: recreate);
  }

  /// Reset all services (e.g., on logout).
  Future<void> resetAllServices({bool recreate = false}) async {
    await _services?.resetAll(recreate: recreate);
  }

  // ============================================================
  // PERSISTENCE (delegated to PersistenceManager)
  // ============================================================

  /// Hydrate the cache from persisted storage.
  ///
  /// Call this during app initialization before rendering any queries.
  Future<void> hydrate() async {
    if (_persistenceManager == null) {
      FluQueryLogger.warn('hydrate() called but no persister configured');
      return;
    }
    await _persistenceManager!.hydrate();
  }

  /// Register persistence options for a query.
  void registerPersistOptions<TData>(
    QueryKey queryKey,
    PersistOptions<TData> options,
  ) {
    _persistenceManager?.registerOptions<TData>(queryKey, options);
  }

  /// Unregister persistence options when an observer unmounts.
  void unregisterPersistOptions(QueryKey queryKey) {
    _persistenceManager?.unregisterOptions(queryKey);
  }

  /// Persist a query to storage.
  Future<void> persistQuery<TData>(
    QueryKey queryKey,
    TData data,
    DateTime? dataUpdatedAt,
  ) async {
    await _persistenceManager?.persist<TData>(queryKey, data, dataUpdatedAt);
  }

  /// Remove a query from persistence.
  Future<void> unpersistQuery(QueryKey queryKey) async {
    await _persistenceManager?.unpersist(queryKey);
  }

  /// Clear all persisted queries.
  Future<void> clearPersistence() async {
    await _persistenceManager?.clear();
  }

  /// Dehydrate - get all persistable queries for manual handling.
  Future<List<PersistedQuery>> dehydrate() async {
    return await _persistenceManager?.dehydrate() ?? [];
  }

  // ============================================================
  // NETWORK STATE
  // ============================================================

  /// Set online status
  void setOnline(bool isOnline) {
    final wasOffline = !_isOnline;
    _isOnline = isOnline;

    if (wasOffline && isOnline) {
      _onReconnect();
    }
  }

  /// Set focus status
  void setFocused(bool isFocused) {
    final wasFocused = _isFocused;
    _isFocused = isFocused;

    if (!wasFocused && isFocused) {
      _onWindowFocus();
    }
  }

  void _onWindowFocus() {
    if (!_isMounted) return;
    FluQueryLogger.debug('Window focus - refetching stale queries');

    final queries = _queryCache.findAll(
      stale: true,
      predicate: (q) =>
          q.hasObservers && (q.options?.refetchOnWindowFocus ?? true),
    );

    for (final query in queries) {
      query.fetch();
    }
  }

  void _onReconnect() {
    if (!_isMounted) return;
    FluQueryLogger.debug('Reconnect - refetching stale queries');

    final queries = _queryCache.findAll(
      stale: true,
      predicate: (q) =>
          q.hasObservers && (q.options?.refetchOnReconnect ?? true),
    );

    for (final query in queries) {
      query.fetch();
    }
  }

  // ============================================================
  // QUERY OPERATIONS
  // ============================================================

  /// Fetch a query
  Future<TData> fetchQuery<TData, TError>({
    required QueryKey queryKey,
    required QueryFn<TData> queryFn,
    StaleTime? staleTime,
  }) async {
    final options = QueryOptions<TData, TError>(
      queryKey: queryKey,
      queryFn: queryFn,
      staleTime: staleTime ?? _config.defaultOptions.staleTime,
      cacheTime: _config.defaultOptions.cacheTime,
      retry: _config.defaultOptions.retry,
      retryDelay: _config.defaultOptions.retryDelay,
    );

    final query = _queryCache.build<TData, TError>(options: options);
    final result = await query.fetch(queryFn: queryFn);
    final dynamic d = result;
    return d;
  }

  /// Prefetch a query
  Future<void> prefetchQuery<TData, TError>({
    required QueryKey queryKey,
    required QueryFn<TData> queryFn,
    StaleTime? staleTime,
  }) async {
    try {
      await fetchQuery<TData, TError>(
        queryKey: queryKey,
        queryFn: queryFn,
        staleTime: staleTime,
      );
    } catch (_) {
      // Prefetch silently fails
    }
  }

  /// Get query data from cache
  TData? getQueryData<TData>(QueryKey queryKey) {
    return _queryCache.getQueryData<TData>(queryKey);
  }

  /// Set query data in cache
  TData? setQueryData<TData>(
    QueryKey queryKey,
    TData data, {
    DateTime? updatedAt,
  }) {
    final query = _queryCache.get<TData, Object>(queryKey);
    if (query != null) {
      query.setData(data, updatedAt: updatedAt);
      return data;
    }

    final options = QueryOptions<TData, Object>(
      queryKey: queryKey,
      initialData: data,
      initialDataUpdatedAt: updatedAt ?? DateTime.now(),
    );
    _queryCache.build<TData, Object>(options: options);
    return data;
  }

  /// Invalidate queries matching a filter
  Future<void> invalidateQueries({
    QueryKey? queryKey,
    RefetchType refetch = RefetchType.active,
    bool Function(Query query)? predicate,
  }) async {
    final queries = _queryCache.findAll(
      queryKey: queryKey,
      predicate: predicate,
    );

    FluQueryLogger.debug(
        'invalidateQueries: found ${queries.length} queries for key=$queryKey, refetch=$refetch');

    for (final query in queries) {
      query.invalidate();
    }

    switch (refetch) {
      case RefetchType.active:
        final activeQueries = queries.where((q) => q.hasObservers).toList();
        await Future.wait(activeQueries.map((q) => q.fetch()));
      case RefetchType.all:
        await Future.wait(queries.map((q) => q.fetch()));
      case RefetchType.none:
        break;
    }
  }

  /// Refetch queries matching a filter
  Future<void> refetchQueries({
    QueryKey? queryKey,
    bool? stale,
    bool activeOnly = true,
    bool Function(Query query)? predicate,
  }) async {
    final queries = _queryCache.findAll(
      queryKey: queryKey,
      stale: stale,
      predicate: (q) {
        if (activeOnly && !q.hasObservers) return false;
        return predicate?.call(q) ?? true;
      },
    );

    await Future.wait(queries.map((q) => q.fetch(forceRefetch: true)));
  }

  /// Cancel queries matching a filter
  void cancelQueries({
    QueryKey? queryKey,
    bool Function(Query query)? predicate,
  }) {
    final queries = _queryCache.findAll(
      queryKey: queryKey,
      fetching: true,
      predicate: predicate,
    );

    for (final query in queries) {
      query.cancel();
    }
  }

  /// Remove queries from cache
  void removeQueries({
    QueryKey? queryKey,
    bool Function(Query query)? predicate,
  }) {
    final queries = _queryCache.findAll(
      queryKey: queryKey,
      predicate: predicate,
    );

    for (final query in queries) {
      _queryCache.remove(query);
    }
  }

  /// Reset all queries to initial state
  void resetQueries({
    QueryKey? queryKey,
    bool Function(Query query)? predicate,
  }) {
    final queries = _queryCache.findAll(
      queryKey: queryKey,
      predicate: predicate,
    );

    for (final query in queries) {
      query.reset();
    }
  }

  /// Get query state
  Query<TData, TError>? getQuery<TData, TError>(QueryKey queryKey) {
    return _queryCache.get<TData, TError>(queryKey);
  }

  /// Check if any queries are fetching
  bool isFetching({QueryKey? queryKey}) {
    if (queryKey == null) {
      return _queryCache.queries.any((q) => q.isFetching);
    }
    return _queryCache.findAll(queryKey: queryKey, fetching: true).isNotEmpty;
  }

  /// Get count of fetching queries
  int fetchingCount({QueryKey? queryKey}) {
    if (queryKey == null) {
      return _queryCache.queries.where((q) => q.isFetching).length;
    }
    return _queryCache.findAll(queryKey: queryKey, fetching: true).length;
  }

  /// Check if any mutations are pending
  bool isMutating() {
    return _mutationCache.mutations.any((m) => m.state.isPending);
  }

  /// Get count of pending mutations
  int mutatingCount() {
    return _mutationCache.mutations.where((m) => m.state.isPending).length;
  }

  // ============================================================
  // INFINITE QUERIES
  // ============================================================

  /// Get or create an infinite query
  InfiniteQuery<TData, TError, TPageParam>
      getInfiniteQuery<TData, TError, TPageParam>(
    InfiniteQueryOptions<TData, TError, TPageParam> options,
  ) {
    final queryHash = QueryKeyUtils.hashKey(options.queryKey);
    var query = _infiniteQueries[queryHash]
        as InfiniteQuery<TData, TError, TPageParam>?;

    if (query == null) {
      query = InfiniteQuery<TData, TError, TPageParam>(
        queryKey: options.queryKey,
        options: options,
      );
      _infiniteQueries[queryHash] = query;
    } else {
      query.setOptions(options);
    }

    return query;
  }

  /// Get or create an infinite query without updating options
  InfiniteQuery<TData, TError, TPageParam>
      getOrCreateInfiniteQuery<TData, TError, TPageParam>({
    required QueryKey queryKey,
    required TPageParam? initialPageParam,
  }) {
    final queryHash = QueryKeyUtils.hashKey(queryKey);
    var query = _infiniteQueries[queryHash]
        as InfiniteQuery<TData, TError, TPageParam>?;

    if (query == null) {
      query = InfiniteQuery<TData, TError, TPageParam>(
        queryKey: queryKey,
        options: InfiniteQueryOptions<TData, TError, TPageParam>(
          queryKey: queryKey,
          queryFn: (_) => throw StateError('queryFn not set'),
          initialPageParam: initialPageParam,
        ),
      );
      _infiniteQueries[queryHash] = query;
    }

    return query;
  }

  // ============================================================
  // STORES (delegated to StoreManager)
  // ============================================================

  /// Create a persistent query store that survives widget lifecycle.
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
    return _storeManager.createStore<TData, TError>(
      queryKey: queryKey,
      queryFn: queryFn,
      staleTime: staleTime,
      retry: retry,
      retryDelay: retryDelay,
      refetchInterval: refetchInterval,
      refetchOnWindowFocus: refetchOnWindowFocus,
      refetchOnReconnect: refetchOnReconnect,
      persist: persist,
    );
  }

  /// Get an existing store by query key
  QueryStore<TData, TError>? getStore<TData, TError>(QueryKey queryKey) {
    return _storeManager.getStore<TData, TError>(queryKey);
  }

  /// Remove and dispose a store
  void removeStore(QueryKey queryKey) {
    _storeManager.removeStore(queryKey);
  }

  /// Subscribe to a query's state changes without creating a store.
  VoidCallback subscribeToQuery<TData, TError>({
    required QueryKey queryKey,
    required QueryFn<TData> queryFn,
    required void Function(QueryState<TData, TError> state) listener,
    StaleTime? staleTime,
    bool fetchOnSubscribe = true,
  }) {
    final options = QueryOptions<TData, TError>(
      queryKey: queryKey,
      queryFn: queryFn,
      staleTime: staleTime ?? _config.defaultOptions.staleTime,
      cacheTime: _config.defaultOptions.cacheTime,
    );

    final query = _queryCache.build<TData, TError>(options: options);
    final unsubscribe = query.subscribe(listener);

    if (fetchOnSubscribe) {
      query.fetch(queryFn: queryFn).catchError((_) => null);
    }

    return unsubscribe;
  }

  // ============================================================
  // CLEANUP
  // ============================================================

  /// Clear all caches
  void clear() {
    _queryCache.clear();
    _mutationCache.clear();
    _infiniteQueries.clear();
    _storeManager.clear();
  }

  /// Dispose the client
  Future<void> dispose() async {
    unmount();

    // Dispose services first (they may depend on caches)
    await _services?.disposeAll();

    _queryCache.dispose();
    _mutationCache.dispose();
    for (final q in _infiniteQueries.values) {
      q.cancel();
    }
    _infiniteQueries.clear();
    _storeManager.dispose();
  }
}
