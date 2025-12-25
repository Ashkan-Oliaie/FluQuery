import 'types.dart';
import 'query.dart';
import 'query_cache.dart';
import 'query_options.dart';
import 'query_key.dart';
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
  Future<void> invalidateQueries({
    QueryKey? queryKey,
    bool? refetchType, // true = active only, false = all, null = none
    bool Function(Query query)? predicate,
  }) async {
    final queries = _queryCache.findAll(
      queryKey: queryKey,
      predicate: predicate,
    );

    FluQueryLogger.debug(
      'invalidateQueries: found ${queries.length} queries for key=$queryKey, refetchType=$refetchType'
    );

    for (final query in queries) {
      query.invalidate();
      FluQueryLogger.debug(
        'invalidateQueries: invalidated ${query.queryKey}, hasObservers=${query.hasObservers}'
      );
    }

    // Refetch active queries
    if (refetchType == true) {
      final activeQueries = queries.where((q) => q.hasObservers).toList();
      FluQueryLogger.debug('invalidateQueries: refetching ${activeQueries.length} active queries');
      await Future.wait(activeQueries.map((q) => q.fetch()));
    } else if (refetchType == false) {
      FluQueryLogger.debug('invalidateQueries: refetching all ${queries.length} queries');
      await Future.wait(queries.map((q) => q.fetch()));
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
    return _queryCache
        .findAll(queryKey: queryKey, fetching: true)
        .isNotEmpty;
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
    var query =
        _infiniteQueries[queryHash] as InfiniteQuery<TData, TError, TPageParam>?;

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

  /// Called when window gains focus
  void _onWindowFocus() {
    if (!_isMounted) return;
    FluQueryLogger.debug('Window focus - refetching stale queries');

    final queries = _queryCache.findAll(
      stale: true,
      predicate: (q) => q.hasObservers && (q.options?.refetchOnWindowFocus ?? true),
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
      predicate: (q) => q.hasObservers && (q.options?.refetchOnReconnect ?? true),
    );

    for (final query in queries) {
      query.fetch();
    }
  }

  /// Clear all caches
  void clear() {
    _queryCache.clear();
    _mutationCache.clear();
    _infiniteQueries.clear();
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
  }
}

