import 'dart:async';
import 'types.dart';
import 'query_key.dart';
import 'query_state.dart';
import 'query_options.dart';
import 'logger.dart';

/// Retryer for handling query retries - uses Object? to avoid web type issues
class Retryer {
  final Future<Object?> Function() fn;
  final int retryCount;
  final RetryDelayFn retryDelay;
  final CancellationToken? signal;
  final bool Function(int failureCount, Object error)? shouldRetry;

  Retryer({
    required this.fn,
    this.retryCount = 3,
    this.retryDelay = defaultRetryDelay,
    this.signal,
    this.shouldRetry,
  });

  Future<Object?> run() async {
    int failureCount = 0;

    while (true) {
      if (signal?.isCancelled == true) {
        throw QueryCancelledException();
      }

      try {
        return await fn();
      } catch (error) {
        failureCount++;

        final canRetry = shouldRetry?.call(failureCount, error) ??
            (failureCount <= retryCount);

        if (!canRetry) {
          rethrow;
        }

        final delay = retryDelay(failureCount - 1, error);
        FluQueryLogger.debug(
            'Query retry $failureCount after ${delay.inMilliseconds}ms');

        await Future.delayed(delay);
      }
    }
  }
}

/// Exception thrown when a query is cancelled
class QueryCancelledException implements Exception {
  @override
  String toString() => 'QueryCancelledException';
}

/// A Query manages the state and lifecycle of a single piece of server data
class Query<TData, TError> {
  final QueryKey queryKey;
  final String queryHash;

  QueryState<TData, TError> _state;
  CancellationToken? _currentCancellationToken;
  Timer? _cacheTimer;

  // Use dynamic to avoid web type issues with callbacks
  final List<void Function(dynamic)> _observers = [];
  Future<Object?>? _currentFetch;

  /// Track all observer options to compute merged options
  final List<QueryOptions<TData, TError>> _observerOptions = [];

  /// Merged options computed from all observers (uses most conservative values)
  QueryOptions<TData, TError>? _mergedOptions;

  /// Callback for when data is successfully fetched (used for persistence)
  void Function(QueryKey key, Object? data, DateTime? dataUpdatedAt)? onDataSuccess;

  Query({
    required this.queryKey,
    String? queryHash,
    QueryState<TData, TError>? initialState,
    QueryOptions<TData, TError>? options,
  })  : queryHash = queryHash ?? QueryKeyUtils.hashKey(queryKey),
        _state = initialState ?? QueryState<TData, TError>(),
        _mergedOptions = options {
    // Apply initial data if provided
    if (options?.initialData != null) {
      _state = _state.withSuccess(options!.initialData,
          updatedAt: options.initialDataUpdatedAt);
    }
  }

  /// Current state of the query
  QueryState<TData, TError> get state => _state;

  /// Current merged options (computed from all observers)
  QueryOptions<TData, TError>? get options => _mergedOptions;

  /// Number of observers
  int get observerCount => _observers.length;

  /// Whether there are any observers
  bool get hasObservers => _observers.isNotEmpty;

  /// Whether the data is stale
  bool get isStale {
    if (_state.isInvalidated) {
      FluQueryLogger.debug('Query.isStale: $queryKey - invalidated=true');
      return true;
    }
    if (_state.dataUpdatedAt == null) {
      FluQueryLogger.debug('Query.isStale: $queryKey - no dataUpdatedAt');
      return true;
    }
    final staleTime = _mergedOptions?.staleTime;
    if (staleTime == null) {
      FluQueryLogger.debug('Query.isStale: $queryKey - no staleTime option');
      return true;
    }
    final result = staleTime.isStale(_state.dataUpdatedAt!);
    final age = DateTime.now().difference(_state.dataUpdatedAt!);
    FluQueryLogger.debug(
        'Query.isStale: $queryKey - staleTime=${staleTime.duration}, age=$age, isStale=$result');
    return result;
  }

  /// Whether the query is currently being fetched
  bool get isFetching => _state.isFetching;

  /// Whether the query is active (has observers)
  bool get isActive => hasObservers;

  /// Whether the query is inactive
  bool get isInactive => !hasObservers;

  /// Whether the query is disabled
  bool get isDisabled => _mergedOptions?.enabled == false;

  /// Update options - deprecated, use addObserverOptions instead
  @Deprecated('Use addObserverOptions/removeObserverOptions instead')
  void setOptions(QueryOptions<TData, TError> options) {
    _mergedOptions = options;
  }

  /// Add observer options and recalculate merged options
  void addObserverOptions(QueryOptions<TData, TError> options) {
    _observerOptions.add(options);
    _recalculateMergedOptions();
    FluQueryLogger.debug('Query.addObserverOptions: $queryKey - observers=${_observerOptions.length}, '
        'staleTime=${_mergedOptions?.staleTime.duration}, cacheTime=${_mergedOptions?.cacheTime.duration}');
  }

  /// Remove observer options and recalculate merged options
  void removeObserverOptions(QueryOptions<TData, TError> options) {
    _observerOptions.remove(options);
    _recalculateMergedOptions();
    FluQueryLogger.debug('Query.removeObserverOptions: $queryKey - observers=${_observerOptions.length}, '
        'staleTime=${_mergedOptions?.staleTime.duration}, cacheTime=${_mergedOptions?.cacheTime.duration}');
  }

  /// Recalculate merged options from all observer options
  /// Uses the most conservative values:
  /// - staleTime: shortest (data becomes stale sooner)
  /// - cacheTime: longest (keep data in cache longer)
  /// - retry: highest (more retries)
  void _recalculateMergedOptions() {
    if (_observerOptions.isEmpty) {
      // Keep last merged options for GC timing
      // This is important: when all observers leave, we still need
      // valid options for GC scheduling
      return;
    }

    final first = _observerOptions.first;

    // Start with first observer's values
    Duration shortestStaleTime = first.staleTime.duration;
    Duration longestCacheTime = first.cacheTime.duration;
    int highestRetry = first.retry;
    RetryDelayFn retryDelay = first.retryDelay;
    QueryFn<TData>? queryFn = first.queryFn ?? _mergedOptions?.queryFn;

    // Merge with other observers
    for (int i = 1; i < _observerOptions.length; i++) {
      final opts = _observerOptions[i];

      // Shortest staleTime (most conservative - data stales faster)
      if (opts.staleTime.duration < shortestStaleTime) {
        shortestStaleTime = opts.staleTime.duration;
      }

      // Longest cacheTime (keep in cache for whoever needs it longest)
      if (opts.cacheTime.duration > longestCacheTime) {
        longestCacheTime = opts.cacheTime.duration;
      }

      // Highest retry count
      if (opts.retry > highestRetry) {
        highestRetry = opts.retry;
      }

      // Use first non-null queryFn
      queryFn ??= opts.queryFn;
    }

    _mergedOptions = QueryOptions<TData, TError>(
      queryKey: first.queryKey,
      queryFn: queryFn,
      staleTime: StaleTime(shortestStaleTime),
      cacheTime: CacheTime(longestCacheTime),
      retry: highestRetry,
      retryDelay: retryDelay,
      // These are observer-specific, use defaults at query level
      refetchOnWindowFocus: true,
      refetchOnReconnect: true,
      refetchOnMount: true,
    );
  }

  /// Add an observer - uses dynamic to avoid web type issues
  void addObserver(void Function(dynamic) observer) {
    _observers.add(observer);
    _stopGc();
    FluQueryLogger.debug(
        'Query.addObserver: $queryKey - observers=${_observers.length}');
  }

  /// Remove an observer
  void removeObserver(void Function(dynamic) observer) {
    _observers.remove(observer);
    FluQueryLogger.debug(
        'Query.removeObserver: $queryKey - observers=${_observers.length}');
    if (!hasObservers) {
      FluQueryLogger.debug('Query.removeObserver: scheduling GC for $queryKey');
      _scheduleGc();
    }
  }

  /// Subscribe to state changes without widget lifecycle
  /// Returns an unsubscribe function
  VoidCallback subscribe(
      void Function(QueryState<TData, TError> state) listener) {
    void wrappedListener(dynamic state) {
      listener(state as QueryState<TData, TError>);
    }

    addObserver(wrappedListener);
    return () => removeObserver(wrappedListener);
  }

  /// Notify all observers of state change
  void _notifyObservers() {
    for (final observer in _observers) {
      observer(_state);
    }
  }

  /// Update state and notify observers
  void _setState(QueryState<TData, TError> newState) {
    _state = newState;
    _notifyObservers();
  }

  /// Fetch data for this query - returns Object? to avoid web type issues
  Future<Object?> fetch({
    QueryFn<TData>? queryFn,
    bool forceRefetch = false,
  }) async {
    final fn = queryFn ?? _mergedOptions?.queryFn;
    if (fn == null) {
      throw StateError('No queryFn provided for query: $queryKey');
    }

    // Return existing fetch if in progress
    if (_currentFetch != null && !forceRefetch) {
      return await _currentFetch!;
    }

    // Check if we should skip fetch (not stale and has data)
    if (!forceRefetch && !isStale && _state.hasData) {
      return _state.data;
    }

    _currentCancellationToken = CancellationToken();

    _setState(_state.copyWith(
      fetchStatus: FetchStatus.fetching,
      clearError: true,
    ));

    final context = QueryFnContext(
      queryKey: queryKey,
      signal: _currentCancellationToken,
      meta: _mergedOptions?.meta ?? {},
    );

    // Use Retryer - cast result to Object? to avoid web generic issues
    final retryer = Retryer(
      fn: () async {
        final dynamic result = await fn(context);
        return result as Object?;
      },
      retryCount: _mergedOptions?.retry ?? 3,
      retryDelay: _mergedOptions?.retryDelay ?? defaultRetryDelay,
      signal: _currentCancellationToken,
    );

    _currentFetch = retryer.run();

    try {
      final rawData = await _currentFetch!;

      // Set state with raw data
      _state = _state.withSuccess(rawData);
      _notifyObservers();

      // Trigger persistence callback if registered
      onDataSuccess?.call(queryKey, rawData, _state.dataUpdatedAt);

      FluQueryLogger.debug('Query success: $queryKey');
      return rawData;
    } catch (error, stackTrace) {
      if (error is QueryCancelledException) {
        _setState(_state.copyWith(
          fetchStatus: FetchStatus.idle,
        ));
        rethrow;
      }

      FluQueryLogger.error('Query error: $queryKey', error, stackTrace);

      // Store error in state
      _state = QueryState<TData, TError>(
        data: _state.hasData ? _state.data : null,
        dataUpdateCount: _state.dataUpdateCount,
        dataUpdatedAt: _state.dataUpdatedAt,
        error: null,
        errorUpdateCount: _state.errorUpdateCount + 1,
        errorUpdatedAt: DateTime.now(),
        fetchFailureCount: _state.fetchFailureCount + 1,
        fetchFailureReason: error,
        status: QueryStatus.error,
        fetchStatus: FetchStatus.idle,
        isInvalidated: _state.isInvalidated,
      );
      _notifyObservers();

      // Rethrow to let caller know fetch failed
      rethrow;
    } finally {
      _currentFetch = null;
    }
  }

  /// Cancel the current fetch
  void cancel() {
    _currentCancellationToken?.cancel();
    _currentCancellationToken = null;
  }

  /// Invalidate the query (mark as stale)
  void invalidate() {
    _setState(_state.copyWith(isInvalidated: true));
  }

  /// Reset the query to initial state
  void reset() {
    cancel();
    _setState(QueryState<TData, TError>.initial());
  }

  /// Set data directly - takes Object? to avoid web type issues
  void setData(Object? data, {DateTime? updatedAt}) {
    _state = _state.withSuccess(data, updatedAt: updatedAt);
    _notifyObservers();
  }

  /// Schedule garbage collection
  void _scheduleGc() {
    _cacheTimer?.cancel();
    final cacheTime = _mergedOptions?.cacheTime ?? CacheTime.defaultTime;
    FluQueryLogger.debug(
        'Query._scheduleGc: $queryKey - cacheTime=${cacheTime.duration}');
    if (cacheTime == CacheTime.infinity) {
      FluQueryLogger.debug('Query._scheduleGc: $queryKey - infinity, skipping');
      return;
    }

    _cacheTimer = Timer(cacheTime.duration, () {
      FluQueryLogger.debug(
          'Query cache expired: $queryKey - hasObservers=$hasObservers');
      _onGc?.call(this);
    });
  }

  /// Stop cache expiration timer
  void _stopGc() {
    _cacheTimer?.cancel();
    _cacheTimer = null;
  }

  /// Callback for garbage collection
  void Function(Query<TData, TError>)? _onGc;

  /// Set the GC callback
  set onGc(void Function(Query<TData, TError>) callback) {
    _onGc = callback;
  }

  /// Destroy the query
  void destroy() {
    cancel();
    _cacheTimer?.cancel();
    _observers.clear();
  }

  @override
  String toString() => 'Query($queryKey, state: $_state)';
}
