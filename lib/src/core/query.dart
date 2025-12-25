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
  QueryOptions<TData, TError>? _options;
  CancellationToken? _currentCancellationToken;
  Timer? _gcTimer;

  // Use dynamic to avoid web type issues with callbacks
  final List<void Function(dynamic)> _observers = [];
  Future<Object?>? _currentFetch;

  Query({
    required this.queryKey,
    String? queryHash,
    QueryState<TData, TError>? initialState,
    QueryOptions<TData, TError>? options,
  })  : queryHash = queryHash ?? QueryKeyUtils.hashKey(queryKey),
        _state = initialState ?? QueryState<TData, TError>(),
        _options = options {
    // Apply initial data if provided
    if (options?.initialData != null) {
      _state = _state.withSuccess(options!.initialData, updatedAt: options.initialDataUpdatedAt);
    }
  }

  /// Current state of the query
  QueryState<TData, TError> get state => _state;

  /// Current options
  QueryOptions<TData, TError>? get options => _options;

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
    final staleTime = _options?.staleTime;
    if (staleTime == null) {
      FluQueryLogger.debug('Query.isStale: $queryKey - no staleTime option');
      return true;
    }
    final result = staleTime.isStale(_state.dataUpdatedAt!);
    final age = DateTime.now().difference(_state.dataUpdatedAt!);
    FluQueryLogger.debug(
      'Query.isStale: $queryKey - staleTime=${staleTime.duration}, age=$age, isStale=$result'
    );
    return result;
  }

  /// Whether the query is currently being fetched
  bool get isFetching => _state.isFetching;

  /// Whether the query is active (has observers)
  bool get isActive => hasObservers;

  /// Whether the query is inactive
  bool get isInactive => !hasObservers;

  /// Whether the query is disabled
  bool get isDisabled => _options?.enabled == false;

  /// Update options
  void setOptions(QueryOptions<TData, TError> options) {
    _options = options;
  }

  /// Add an observer - uses dynamic to avoid web type issues
  void addObserver(void Function(dynamic) observer) {
    _observers.add(observer);
    _stopGc();
  }

  /// Remove an observer
  void removeObserver(void Function(dynamic) observer) {
    _observers.remove(observer);
    if (!hasObservers) {
      _scheduleGc();
    }
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
    final fn = queryFn ?? _options?.queryFn;
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
      meta: _options?.meta ?? {},
    );

    // Use Retryer - cast result to Object? to avoid web generic issues
    final retryer = Retryer(
      fn: () async {
        final dynamic result = await fn(context);
        return result as Object?;
      },
      retryCount: _options?.retry ?? 3,
      retryDelay: _options?.retryDelay ?? defaultRetryDelay,
      signal: _currentCancellationToken,
    );

    _currentFetch = retryer.run();

    try {
      final rawData = await _currentFetch!;

      // Set state with raw data
      _state = _state.withSuccess(rawData);
      _notifyObservers();

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
    _gcTimer?.cancel();
    final gcTime = _options?.gcTime ?? GcTime.defaultTime;
    if (gcTime == GcTime.infinity) return;

    _gcTimer = Timer(gcTime.duration, () {
      FluQueryLogger.debug('Query garbage collected: $queryKey');
      _onGc?.call(this);
    });
  }

  /// Stop garbage collection timer
  void _stopGc() {
    _gcTimer?.cancel();
    _gcTimer = null;
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
    _gcTimer?.cancel();
    _observers.clear();
  }

  @override
  String toString() => 'Query($queryKey, state: $_state)';
}
