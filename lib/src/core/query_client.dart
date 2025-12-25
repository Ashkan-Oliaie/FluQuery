import 'types.dart';
import 'query.dart';
import 'query_cache.dart';
import 'query_options.dart';
import 'query_key.dart';
import 'query_state.dart';
import 'query_store.dart';
import 'mutation_cache.dart';
import 'infinite_query.dart';
import 'logger.dart';

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
  final GcTime gcTime;
  final bool refetchOnWindowFocus;
  final bool refetchOnReconnect;
  final bool refetchOnMount;
  final int retry;
  final RetryDelayFn retryDelay;
  final NetworkMode networkMode;

  const DefaultQueryOptions({
    this.staleTime = StaleTime.zero,
    this.gcTime = GcTime.defaultTime,
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

  bool _isOnline = true;
  bool _isFocused = true;
  bool _isMounted = false;

  QueryClient({
    QueryCache? queryCache,
    MutationCache? mutationCache,
    QueryClientConfig config = QueryClientConfig.defaultConfig,
  })  : _queryCache = queryCache ?? QueryCache(),
        _mutationCache = mutationCache ?? MutationCache(),
        _config = config {
    FluQueryLogger.level = config.logLevel;
  }

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
      gcTime: _config.defaultOptions.gcTime,
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
      gcTime: _config.defaultOptions.gcTime,
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
