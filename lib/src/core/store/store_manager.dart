import '../common/common.dart';
import '../query/query.dart';
import '../persistence/persistence.dart';

/// Manages QueryStore lifecycle - creation, caching, and disposal.
///
/// QueryStores are persistent query observers that survive widget lifecycle,
/// ideal for global data like user sessions or app config.
class StoreManager {
  final QueryCache _queryCache;
  final DefaultQueryOptions _defaultOptions;
  final Map<String, QueryStore> _stores = {};

  /// Callbacks for persistence integration (optional)
  final void Function<TData>(QueryKey, PersistOptions<TData>)? _persistRegistrar;
  final Future<void> Function<TData>(QueryKey, TData, DateTime?)? _persistCallback;

  StoreManager({
    required QueryCache queryCache,
    required DefaultQueryOptions defaultOptions,
    void Function<TData>(QueryKey, PersistOptions<TData>)? persistRegistrar,
    Future<void> Function<TData>(QueryKey, TData, DateTime?)? persistCallback,
  })  : _queryCache = queryCache,
        _defaultOptions = defaultOptions,
        _persistRegistrar = persistRegistrar,
        _persistCallback = persistCallback;

  /// Get all active stores
  Iterable<QueryStore> get stores => _stores.values.where((s) => !s.isDisposed);

  /// Create a persistent query store that survives widget lifecycle.
  ///
  /// Stores are ideal for:
  /// - Global data that should always be fresh (user session, settings)
  /// - Background polling without widgets
  /// - Data accessed from multiple places
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

  /// Clear all stores
  void clear() {
    for (final store in _stores.values) {
      store.dispose();
    }
    _stores.clear();
  }

  /// Dispose all stores
  void dispose() {
    clear();
  }
}

