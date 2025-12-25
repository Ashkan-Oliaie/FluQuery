import 'dart:async';
import 'types.dart';
import 'query.dart';
import 'query_key.dart';
import 'query_options.dart';
import 'query_state.dart';
import 'logger.dart';

/// Event types for query cache
enum QueryCacheEventType {
  added,
  removed,
  updated,
}

/// Event emitted by the query cache
class QueryCacheEvent {
  final QueryCacheEventType type;
  final Query query;

  QueryCacheEvent({required this.type, required this.query});
}

/// Cache for storing and managing queries
class QueryCache {
  final Map<String, Query> _queries = {};
  final StreamController<QueryCacheEvent> _eventController =
      StreamController<QueryCacheEvent>.broadcast();

  /// Stream of cache events
  Stream<QueryCacheEvent> get events => _eventController.stream;

  /// Get all queries
  Iterable<Query> get queries => _queries.values;

  /// Number of queries in the cache
  int get length => _queries.length;

  /// Build a query from options
  Query<TData, TError> build<TData, TError>({
    required QueryOptions<TData, TError> options,
    QueryState<TData, TError>? state,
  }) {
    final queryHash = QueryKeyUtils.hashKey(options.queryKey);

    // Check if query exists with same hash
    final existing = _queries[queryHash];
    if (existing != null) {
      // Query exists - update options and return wrapper
      existing.setOptions(options as dynamic);
      return _TypedQueryWrapper<TData, TError>(existing);
    }

    // Create new query
    final query = Query<TData, TError>(
      queryKey: options.queryKey,
      queryHash: queryHash,
      options: options,
      initialState: state,
    );

    query.onGc = _onQueryGc;
    _add(query);
    return query;
  }

  /// Add a query to the cache
  void _add(Query query) {
    if (_queries.containsKey(query.queryHash)) return;

    _queries[query.queryHash] = query;
    FluQueryLogger.debug('Query added to cache: ${query.queryKey}');

    _eventController.add(QueryCacheEvent(
      type: QueryCacheEventType.added,
      query: query,
    ));
  }

  /// Remove a query from the cache
  void remove(Query query) {
    if (!_queries.containsKey(query.queryHash)) return;

    _queries.remove(query.queryHash);
    query.destroy();
    FluQueryLogger.debug('Query removed from cache: ${query.queryKey}');

    _eventController.add(QueryCacheEvent(
      type: QueryCacheEventType.removed,
      query: query,
    ));
  }

  /// Get a query by key (untyped)
  Query? getUntyped(QueryKey queryKey) {
    final queryHash = QueryKeyUtils.hashKey(queryKey);
    return _queries[queryHash];
  }

  /// Get a typed query by key
  Query<TData, TError>? get<TData, TError>(QueryKey queryKey) {
    final query = getUntyped(queryKey);
    if (query == null) return null;
    return _TypedQueryWrapper<TData, TError>(query);
  }

  /// Get a query by hash
  Query? getByHash(String queryHash) {
    return _queries[queryHash];
  }

  /// Find queries matching a filter
  List<Query> findAll({
    QueryKey? queryKey,
    bool? stale,
    bool? fetching,
    bool Function(Query query)? predicate,
  }) {
    return _queries.values.where((query) {
      if (queryKey != null &&
          !QueryKeyUtils.matchesFilter(query.queryKey, queryKey)) {
        return false;
      }
      if (stale != null && query.isStale != stale) {
        return false;
      }
      if (fetching != null && query.isFetching != fetching) {
        return false;
      }
      if (predicate != null && !predicate(query)) {
        return false;
      }
      return true;
    }).toList();
  }

  /// Get query data by key
  TData? getQueryData<TData>(QueryKey queryKey) {
    final query = getUntyped(queryKey);
    if (query == null) return null;
    final data = query.state.data;
    if (data == null) return null;
    final dynamic d = data;
    return d;
  }

  /// Set query data by key
  TData? setQueryData<TData>(
    QueryKey queryKey,
    TData data, {
    DateTime? updatedAt,
  }) {
    final query = getUntyped(queryKey);
    if (query != null) {
      query.setData(data, updatedAt: updatedAt);
      return data;
    }
    return null;
  }

  /// Clear the cache
  void clear() {
    for (final query in _queries.values.toList()) {
      remove(query);
    }
  }

  /// Callback when a query is garbage collected
  void _onQueryGc(Query query) {
    if (query.isInactive) {
      remove(query);
    }
  }

  /// Notify observers of a query update
  void notifyUpdate(Query query) {
    _eventController.add(QueryCacheEvent(
      type: QueryCacheEventType.updated,
      query: query,
    ));
  }

  /// Dispose the cache
  void dispose() {
    clear();
    _eventController.close();
  }
}

/// Typed wrapper around an untyped query to avoid web runtime cast issues
class _TypedQueryWrapper<TData, TError> implements Query<TData, TError> {
  final Query _inner;

  _TypedQueryWrapper(this._inner);

  @override
  QueryKey get queryKey => _inner.queryKey;

  @override
  String get queryHash => _inner.queryHash;

  @override
  QueryState<TData, TError> get state {
    final innerState = _inner.state;

    // Use rawData/rawError to bypass type checking
    return QueryState<TData, TError>(
      data: innerState.rawData,
      dataUpdateCount: innerState.dataUpdateCount,
      dataUpdatedAt: innerState.dataUpdatedAt,
      error: innerState.rawError,
      errorUpdateCount: innerState.errorUpdateCount,
      errorUpdatedAt: innerState.errorUpdatedAt,
      fetchFailureCount: innerState.fetchFailureCount,
      fetchFailureReason: innerState.fetchFailureReason,
      status: innerState.status,
      fetchStatus: innerState.fetchStatus,
      isInvalidated: innerState.isInvalidated,
    );
  }

  @override
  QueryOptions<TData, TError>? get options {
    final dynamic o = _inner.options;
    return o;
  }

  @override
  int get observerCount => _inner.observerCount;

  @override
  bool get hasObservers => _inner.hasObservers;

  @override
  bool get isStale => _inner.isStale;

  @override
  bool get isFetching => _inner.isFetching;

  @override
  bool get isActive => _inner.isActive;

  @override
  bool get isInactive => _inner.isInactive;

  @override
  bool get isDisabled => _inner.isDisabled;

  @override
  void setOptions(QueryOptions<TData, TError> options) {
    _inner.setOptions(options as dynamic);
  }

  @override
  void addObserver(void Function(dynamic) observer) {
    _inner.addObserver(observer);
  }

  @override
  void removeObserver(void Function(dynamic) observer) {
    _inner.removeObserver(observer);
  }

  @override
  VoidCallback subscribe(
      void Function(QueryState<TData, TError> state) listener) {
    return _inner.subscribe((state) {
      // Convert inner state to typed state
      listener(QueryState<TData, TError>(
        data: state.rawData,
        dataUpdateCount: state.dataUpdateCount,
        dataUpdatedAt: state.dataUpdatedAt,
        error: state.rawError,
        errorUpdateCount: state.errorUpdateCount,
        errorUpdatedAt: state.errorUpdatedAt,
        fetchFailureCount: state.fetchFailureCount,
        fetchFailureReason: state.fetchFailureReason,
        status: state.status,
        fetchStatus: state.fetchStatus,
        isInvalidated: state.isInvalidated,
      ));
    });
  }

  @override
  Future<Object?> fetch(
      {QueryFn<TData>? queryFn, bool forceRefetch = false}) async {
    return await _inner.fetch(
      queryFn: queryFn != null ? (ctx) => queryFn(ctx) : null,
      forceRefetch: forceRefetch,
    );
  }

  @override
  void cancel() => _inner.cancel();

  @override
  void invalidate() => _inner.invalidate();

  @override
  void reset() => _inner.reset();

  @override
  void setData(Object? data, {DateTime? updatedAt}) {
    _inner.setData(data, updatedAt: updatedAt);
  }

  @override
  void destroy() => _inner.destroy();

  @override
  set onGc(void Function(Query<TData, TError>) callback) {
    _inner.onGc = (q) => callback(this);
  }

  @override
  String toString() => _inner.toString();
}
