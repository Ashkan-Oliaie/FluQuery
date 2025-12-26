import 'common/common.dart';
import 'query/query.dart';
import 'mutation/mutation.dart';
import 'persistence/persistence.dart';

/// Configuration for QueryClient
class QueryClientConfig {
  final DefaultQueryOptions defaultOptions;
  final LogLevel logLevel;

  const QueryClientConfig({
    DefaultQueryOptions? defaultOptions,
    this.logLevel = LogLevel.warn,
  }) : defaultOptions = defaultOptions ?? const DefaultQueryOptions();

  const QueryClientConfig._default()
      : defaultOptions = const DefaultQueryOptions(),
        logLevel = LogLevel.warn;

  static const QueryClientConfig defaultConfig = QueryClientConfig._default();
}

/// Default query options with const constructor
class DefaultQueryOptions {
  final StaleTime staleTime;
  final CacheTime cacheTime;
  final bool refetchOnWindowFocus;
  final bool refetchOnReconnect;
  final bool refetchOnMount;
  final int retry;
  final RetryDelayFn retryDelay;
  final NetworkMode networkMode;

  const DefaultQueryOptions({
    this.staleTime = StaleTime.zero,
    this.cacheTime = CacheTime.defaultTime,
    this.refetchOnWindowFocus = true,
    this.refetchOnReconnect = true,
    this.refetchOnMount = true,
    this.retry = 3,
    this.retryDelay = defaultRetryDelay,
    this.networkMode = NetworkMode.online,
  });
}

/// The main client for managing queries and mutations
class QueryClient {
  final QueryCache _queryCache;
  final MutationCache _mutationCache;
  final QueryClientConfig _config;
  final Map<String, InfiniteQuery> _infiniteQueries = {};
  final Map<String, QueryStore> _stores = {};

  /// Persister for saving/restoring query data
  final Persister? _persister;

  /// Track which queries have persistence enabled and their serializers
  /// Uses first-wins strategy: first observer to register persistence options
  /// determines the serializer used for that query key.
  final Map<String, PersistOptions> _persistOptions = {};

  /// Track how many observers are using persistence for each query
  /// When count drops to 0, we can optionally clean up (but keep persisted data)
  final Map<String, int> _persistObserverCounts = {};

  bool _isOnline = true;
  bool _isFocused = true;
  bool _isMounted = false;
  bool _isHydrated = false;

  QueryClient({
    QueryCache? queryCache,
    MutationCache? mutationCache,
    QueryClientConfig config = QueryClientConfig.defaultConfig,
    Persister? persister,
  })  : _queryCache = queryCache ?? QueryCache(),
        _mutationCache = mutationCache ?? MutationCache(),
        _config = config,
        _persister = persister {
    FluQueryLogger.level = config.logLevel;

    // Wire up persistence callback
    if (_persister != null) {
      _queryCache.onDataSuccess = _onQueryDataSuccess;
    }
  }

  /// Called when a query successfully fetches data
  void _onQueryDataSuccess(QueryKey queryKey, Object? data, DateTime? dataUpdatedAt) {
    if (data == null) return;

    final hash = QueryKeyUtils.hashKey(queryKey);
    final persistOpts = _persistOptions[hash];
    if (persistOpts == null) return;

    // Fire and forget persistence
    persistQuery(queryKey, data, dataUpdatedAt);
  }

  /// Whether the cache has been hydrated from persistence
  bool get isHydrated => _isHydrated;

  /// The persister instance (if configured)
  Persister? get persister => _persister;

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
  // PERSISTENCE
  // ============================================================

  /// Hydrate the cache from persisted storage.
  ///
  /// Call this during app initialization before rendering any queries.
  /// This restores previously cached query data from disk.
  ///
  /// Example:
  /// ```dart
  /// void main() async {
  ///   WidgetsFlutterBinding.ensureInitialized();
  ///
  ///   final persister = HivePersister(...);
  ///   await persister.init();
  ///
  ///   final queryClient = QueryClient(persister: persister);
  ///   await queryClient.hydrate();
  ///
  ///   runApp(QueryClientProvider(client: queryClient, child: MyApp()));
  /// }
  /// ```
  Future<void> hydrate() async {
    if (_persister == null) {
      FluQueryLogger.warn('hydrate() called but no persister configured');
      return;
    }

    if (_isHydrated) {
      FluQueryLogger.debug('Cache already hydrated, skipping');
      return;
    }

    try {
      final persistedQueries = await _persister.restoreAll();
      FluQueryLogger.info('Hydrating ${persistedQueries.length} queries from persistence');

      for (final persisted in persistedQueries) {
        try {
          // Store the persisted data in cache
          // The actual deserialization happens when the query is used
          // because we need the serializer from PersistOptions
          _queryCache.hydrateQuery(
            queryKey: persisted.queryKey,
            queryHash: persisted.queryHash,
            serializedData: persisted.serializedData,
            dataUpdatedAt: persisted.dataUpdatedAt,
          );
          FluQueryLogger.debug('Hydrated query: ${persisted.queryKey} (updated: ${persisted.dataUpdatedAt})');
        } catch (e) {
          FluQueryLogger.error('Failed to hydrate query ${persisted.queryKey}: $e');
        }
      }

      _isHydrated = true;
      FluQueryLogger.info('Cache hydration complete');
    } catch (e) {
      FluQueryLogger.error('Failed to hydrate cache: $e');
      _isHydrated = true; // Mark as hydrated anyway to prevent blocking
    }
  }

  /// Register persistence options for a query.
  /// Called internally by useQuery when persist option is set.
  ///
  /// Uses first-wins strategy: the first observer to register persistence
  /// options determines the serializer and maxAge for that query key.
  /// Subsequent observers with different options will use the existing config.
  ///
  /// Also deserializes any hydrated data using the serializer and validates maxAge.
  void registerPersistOptions<TData>(
    QueryKey queryKey,
    PersistOptions<TData> options,
  ) {
    final hash = QueryKeyUtils.hashKey(queryKey);

    // Increment observer count
    _persistObserverCounts[hash] = (_persistObserverCounts[hash] ?? 0) + 1;

    // First-wins: only use options from first observer
    if (_persistOptions.containsKey(hash)) {
      FluQueryLogger.debug(
          'PersistOptions already registered for $queryKey, using existing (observer count: ${_persistObserverCounts[hash]})');
      // Still try to deserialize with existing options if needed
      _tryDeserializeHydratedData<TData>(queryKey, _persistOptions[hash]!);
      return;
    }

    _persistOptions[hash] = options;
    FluQueryLogger.debug('Registered PersistOptions for $queryKey');

    // Try to deserialize any hydrated data
    _tryDeserializeHydratedData<TData>(queryKey, options);
  }

  /// Try to deserialize hydrated data for a query.
  ///
  /// This method:
  /// 1. Validates maxAge - discards data older than maxAge
  /// 2. Attempts deserialization using the provided serializer
  /// 3. Handles schema changes gracefully - if deserialization fails
  ///    (e.g., due to a model change between app versions), the corrupted
  ///    data is removed and a fresh fetch will occur
  void _tryDeserializeHydratedData<TData>(
    QueryKey queryKey,
    PersistOptions options,
  ) {
    final existingQuery = _queryCache.getUntyped(queryKey);
    if (existingQuery == null || existingQuery.state.rawData == null) {
      return;
    }

    final rawData = existingQuery.state.rawData;
    final dataUpdatedAt = existingQuery.state.dataUpdatedAt;

    // Validate maxAge - discard stale persisted data
    if (options.maxAge != null && dataUpdatedAt != null) {
      final age = DateTime.now().difference(dataUpdatedAt);
      if (age > options.maxAge!) {
        FluQueryLogger.debug(
            'Hydrated data for $queryKey exceeded maxAge (${age.inMinutes}m > ${options.maxAge!.inMinutes}m), discarding');
        _queryCache.remove(existingQuery);
        unpersistQuery(queryKey);
        return;
      }
    }

    // Check if data is already the correct type (not serialized JSON)
    if (rawData is TData) {
      return; // Already deserialized
    }

    // Try to deserialize the hydrated data
    try {
      final deserialized = options.serializer.deserialize(rawData);
      // Update the query state with deserialized data
      _queryCache.setQueryData<TData>(
        queryKey,
        deserialized,
        updatedAt: dataUpdatedAt,
      );
      FluQueryLogger.debug('Deserialized hydrated data for: $queryKey');
    } catch (e, stackTrace) {
      // Deserialization failed - likely due to schema change between app versions
      // This is expected when:
      // - A field was added/removed from the model
      // - A field type changed
      // - The serializer logic changed
      FluQueryLogger.warn(
          'Schema mismatch for $queryKey - persisted data incompatible with current model. '
          'Discarding stale data and fetching fresh.');
      FluQueryLogger.debug('Deserialization error: $e', e, stackTrace);

      // Remove corrupted data from cache
      _queryCache.remove(existingQuery);

      // Optionally remove from persistence (default: true)
      if (options.removeOnDeserializationError) {
        unpersistQuery(queryKey);
      }
      // Query will fetch fresh data on next access - no error thrown
    }
  }

  /// Unregister persistence options when an observer unmounts.
  /// Called internally by useQuery dispose.
  void unregisterPersistOptions(QueryKey queryKey) {
    final hash = QueryKeyUtils.hashKey(queryKey);
    final count = _persistObserverCounts[hash] ?? 0;

    if (count <= 1) {
      // Last observer - keep the options registered for potential
      // future observers and to allow background persistence
      _persistObserverCounts.remove(hash);
      FluQueryLogger.debug('Last persistence observer unregistered for $queryKey (keeping options)');
    } else {
      _persistObserverCounts[hash] = count - 1;
      FluQueryLogger.debug('Persistence observer unregistered for $queryKey (remaining: ${count - 1})');
    }
  }

  /// Persist a query to storage.
  /// Called automatically when query data is updated.
  ///
  /// Note: This is typically called internally. For manual persistence,
  /// prefer using the `persist` option on `useQuery`.
  Future<void> persistQuery<TData>(
    QueryKey queryKey,
    TData data,
    DateTime? dataUpdatedAt,
  ) async {
    if (_persister == null) return;
    if (data == null) return; // Don't persist null data

    final hash = QueryKeyUtils.hashKey(queryKey);
    final options = _persistOptions[hash];
    if (options == null) return;

    try {
      final serializer = options.serializer as QueryDataSerializer<TData>;
      final serialized = serializer.serialize(data);

      // Apply keyPrefix if set
      final effectiveHash = options.getEffectiveHash(hash);

      final persisted = PersistedQuery(
        queryKey: queryKey,
        queryHash: effectiveHash,
        serializedData: serialized,
        dataUpdatedAt: dataUpdatedAt,
        persistedAt: DateTime.now(),
        status: 'success',
      );

      await _persister.persistQuery(persisted);
      FluQueryLogger.debug('Persisted query: $queryKey (hash: $effectiveHash)');
    } catch (e) {
      FluQueryLogger.error('Failed to persist query $queryKey: $e');
    }
  }

  /// Remove a query from persistence.
  Future<void> unpersistQuery(QueryKey queryKey) async {
    if (_persister == null) return;

    final hash = QueryKeyUtils.hashKey(queryKey);
    final options = _persistOptions[hash];

    // Apply keyPrefix if set
    final effectiveHash = options?.getEffectiveHash(hash) ?? hash;

    await _persister.removeQuery(effectiveHash);
    _persistOptions.remove(hash);
    FluQueryLogger.debug('Unpersisted query: $queryKey');
  }

  /// Clear all persisted queries.
  Future<void> clearPersistence() async {
    if (_persister == null) return;

    await _persister.clear();
    _persistOptions.clear();
    FluQueryLogger.info('Cleared all persisted queries');
  }

  /// Dehydrate - get all persistable queries for manual handling.
  /// Useful for saving state before app termination.
  Future<List<PersistedQuery>> dehydrate() async {
    final results = <PersistedQuery>[];

    for (final query in _queryCache.getAll()) {
      final hash = query.queryHash;
      final options = _persistOptions[hash];
      if (options == null) continue;

      final data = query.state.rawData;
      if (data == null) continue;

      try {
        final serialized = options.serializer.serialize(data);
        results.add(PersistedQuery(
          queryKey: query.queryKey,
          queryHash: hash,
          serializedData: serialized,
          dataUpdatedAt: query.state.dataUpdatedAt,
          persistedAt: DateTime.now(),
          status: query.state.status.name,
        ));
      } catch (e) {
        FluQueryLogger.error('Failed to dehydrate query ${query.queryKey}: $e');
      }
    }

    return results;
  }

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

    // Create a new query with the data
    final options = QueryOptions<TData, Object>(
      queryKey: queryKey,
      initialData: data,
      initialDataUpdatedAt: updatedAt ?? DateTime.now(),
    );
    _queryCache.build<TData, Object>(options: options);
    return data;
  }

  /// Invalidate queries matching a filter
  ///
  /// [refetch] controls whether to refetch after invalidation:
  /// - [RefetchType.active]: Refetch only queries with active observers (default)
  /// - [RefetchType.all]: Refetch all matching queries
  /// - [RefetchType.none]: Just mark as stale, don't refetch
  ///
  /// @deprecated [refetchType] is deprecated. Use [refetch] instead.
  Future<void> invalidateQueries({
    QueryKey? queryKey,
    @Deprecated('Use refetch parameter instead') bool? refetchType,
    RefetchType refetch = RefetchType.active,
    bool Function(Query query)? predicate,
  }) async {
    // Handle backward compatibility: convert bool? to RefetchType
    final effectiveRefetch = refetchType != null
        ? (refetchType == true
            ? RefetchType.active
            : refetchType == false
                ? RefetchType.all
                : RefetchType.none)
        : refetch;

    final queries = _queryCache.findAll(
      queryKey: queryKey,
      predicate: predicate,
    );

    FluQueryLogger.debug(
        'invalidateQueries: found ${queries.length} queries for key=$queryKey, refetch=$effectiveRefetch');

    for (final query in queries) {
      query.invalidate();
      FluQueryLogger.debug(
          'invalidateQueries: invalidated ${query.queryKey}, hasObservers=${query.hasObservers}');
    }

    // Refetch based on strategy
    switch (effectiveRefetch) {
      case RefetchType.active:
        final activeQueries = queries.where((q) => q.hasObservers).toList();
        FluQueryLogger.debug(
            'invalidateQueries: refetching ${activeQueries.length} active queries');
        await Future.wait(activeQueries.map((q) => q.fetch()));
      case RefetchType.all:
        FluQueryLogger.debug(
            'invalidateQueries: refetching all ${queries.length} queries');
        await Future.wait(queries.map((q) => q.fetch()));
      case RefetchType.none:
        FluQueryLogger.debug('invalidateQueries: skipping refetch');
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
  /// Used by hooks to get cached query with preserved state
  InfiniteQuery<TData, TError, TPageParam>
      getOrCreateInfiniteQuery<TData, TError, TPageParam>({
    required QueryKey queryKey,
    required TPageParam? initialPageParam,
  }) {
    final queryHash = QueryKeyUtils.hashKey(queryKey);
    var query = _infiniteQueries[queryHash]
        as InfiniteQuery<TData, TError, TPageParam>?;

    if (query == null) {
      // Create with minimal options - they will be set by the hook
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

  /// Called when window gains focus
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

  /// Called when device reconnects
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

  // ===== Store Management =====

  /// Create a persistent query store that survives widget lifecycle.
  ///
  /// Stores are ideal for:
  /// - Global data that should always be fresh (user session, settings)
  /// - Background polling without widgets
  /// - Data accessed from multiple places
  ///
  /// Example:
  /// ```dart
  /// final userStore = client.createStore<User, Object>(
  ///   queryKey: ['user'],
  ///   queryFn: fetchUser,
  ///   refetchInterval: Duration(minutes: 5),
  ///   persist: PersistOptions(
  ///     serializer: UserSerializer(),
  ///     maxAge: Duration(days: 7),
  ///   ),
  /// );
  ///
  /// // Access anywhere
  /// final user = userStore.data;
  /// userStore.subscribe((state) => print(state.data));
  /// ```
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
    final queryHash = QueryKeyUtils.hashKey(queryKey);

    // Check if store already exists
    final existing = _stores[queryHash];
    if (existing != null && !existing.isDisposed) {
      return existing as QueryStore<TData, TError>;
    }

    final store = QueryStore<TData, TError>(
      queryKey: queryKey,
      queryFn: queryFn,
      cache: _queryCache,
      staleTime: staleTime ?? _config.defaultOptions.staleTime,
      retry: retry ?? _config.defaultOptions.retry,
      retryDelay: retryDelay ?? _config.defaultOptions.retryDelay,
      refetchInterval: refetchInterval,
      refetchOnWindowFocus: refetchOnWindowFocus,
      refetchOnReconnect: refetchOnReconnect,
      persist: persist,
      persistRegistrar: _persister != null ? registerPersistOptions : null,
      persistCallback: _persister != null ? persistQuery : null,
    );

    _stores[queryHash] = store;
    return store;
  }

  /// Get an existing store by query key
  QueryStore<TData, TError>? getStore<TData, TError>(QueryKey queryKey) {
    final queryHash = QueryKeyUtils.hashKey(queryKey);
    final store = _stores[queryHash];
    if (store == null || store.isDisposed) return null;
    return store as QueryStore<TData, TError>;
  }

  /// Remove and dispose a store
  void removeStore(QueryKey queryKey) {
    final queryHash = QueryKeyUtils.hashKey(queryKey);
    final store = _stores.remove(queryHash);
    store?.dispose();
  }

  /// Get all active stores
  Iterable<QueryStore> get stores => _stores.values.where((s) => !s.isDisposed);

  /// Subscribe to a query's state changes without creating a store.
  /// Returns an unsubscribe function.
  ///
  /// This is lighter than createStore - it just subscribes to an existing
  /// or new query without the persistent polling features.
  ///
  /// Example:
  /// ```dart
  /// final unsubscribe = client.subscribe<User, Object>(
  ///   queryKey: ['user'],
  ///   queryFn: fetchUser,
  ///   listener: (state) => print('User: ${state.data}'),
  /// );
  ///
  /// // Later
  /// unsubscribe();
  /// ```
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

    // Optionally fetch on subscribe
    if (fetchOnSubscribe) {
      query.fetch(queryFn: queryFn).catchError((_) => null);
    }

    return unsubscribe;
  }

  /// Clear all caches
  void clear() {
    _queryCache.clear();
    _mutationCache.clear();
    _infiniteQueries.clear();
    for (final store in _stores.values) {
      store.dispose();
    }
    _stores.clear();
  }

  /// Dispose the client
  void dispose() {
    unmount();
    _queryCache.dispose();
    _mutationCache.dispose();
    for (final q in _infiniteQueries.values) {
      q.cancel();
    }
    _infiniteQueries.clear();
    for (final store in _stores.values) {
      store.dispose();
    }
    _stores.clear();
  }
}
