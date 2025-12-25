import 'dart:async';
import 'types.dart';
import 'query.dart';
import 'query_cache.dart';
import 'query_options.dart';
import 'logger.dart';

/// Result returned by a query observer
/// Uses Object? internally to avoid web runtime generic cast issues
class QueryResult<TData, TError> {
  final Object? _data;
  final Object? _error;
  final QueryStatus status;
  final FetchStatus fetchStatus;
  final bool isLoading;
  final bool isFetching;
  final bool isPending;
  final bool isError;
  final bool isSuccess;
  final bool isRefetching;
  final bool isStale;
  final bool isPaused;
  final bool hasData;
  final DateTime? dataUpdatedAt;
  final DateTime? errorUpdatedAt;
  final int failureCount;
  final Object? failureReason;
  final Future<TData> Function() refetch;

  /// Whether the data is placeholder data
  final bool isPlaceholderData;

  /// Whether the data is from a previous query (keepPreviousData)
  final bool isPreviousData;

  QueryResult({
    required Object? data,
    required Object? error,
    required this.status,
    required this.fetchStatus,
    required this.isLoading,
    required this.isFetching,
    required this.isPending,
    required this.isError,
    required this.isSuccess,
    required this.isRefetching,
    required this.isStale,
    required this.isPaused,
    required this.hasData,
    required this.dataUpdatedAt,
    required this.errorUpdatedAt,
    required this.failureCount,
    required this.failureReason,
    required this.refetch,
    this.isPlaceholderData = false,
    this.isPreviousData = false,
  })  : _data = data,
        _error = error;

  /// Get data using dynamic to avoid web runtime cast issues
  TData? get data {
    if (_data == null) return null;
    final dynamic d = _data;
    return d;
  }

  /// Get error using dynamic to avoid web runtime cast issues
  TError? get error {
    if (_error == null) return null;
    final dynamic e = _error;
    return e;
  }

  /// Raw error without type casting - for internal use
  Object? get rawError => _error;

  /// Raw data without type casting - for internal use
  Object? get rawData => _data;

  /// Create from query
  static QueryResult<TData, TError> fromQuery<TData, TError>(
    Query<TData, TError> query,
  ) {
    final state = query.state;

    // Use rawData/rawError to bypass type checking which fails on web with erased generics
    final Object? rawData = state.rawData;
    final Object? rawError = state.rawError;

    return QueryResult<TData, TError>(
      data: rawData,
      error: rawError,
      status: state.status,
      fetchStatus: state.fetchStatus,
      isLoading: state.isLoading,
      isFetching: state.isFetching,
      isPending: state.isPending,
      isError: state.isError,
      isSuccess: state.isSuccess,
      isRefetching: state.isRefetching,
      isStale: query.isStale,
      isPaused: state.isPaused,
      hasData: state.hasData,
      dataUpdatedAt: state.dataUpdatedAt,
      errorUpdatedAt: state.errorUpdatedAt,
      failureCount: state.fetchFailureCount,
      failureReason: state.fetchFailureReason,
      refetch: () async {
        final result = await query.fetch(forceRefetch: true);
        final dynamic d = result;
        return d;
      },
    );
  }

  /// Create loading state
  factory QueryResult.loading({
    required Future<TData> Function() refetch,
  }) {
    return QueryResult<TData, TError>(
      data: null,
      error: null,
      status: QueryStatus.pending,
      fetchStatus: FetchStatus.fetching,
      isLoading: true,
      isFetching: true,
      isPending: true,
      isError: false,
      isSuccess: false,
      isRefetching: false,
      isStale: true,
      isPaused: false,
      hasData: false,
      dataUpdatedAt: null,
      errorUpdatedAt: null,
      failureCount: 0,
      failureReason: null,
      refetch: refetch,
    );
  }

  @override
  String toString() =>
      'QueryResult(status: $status, data: $_data, error: $_error)';
}

/// Observer for a query that manages subscriptions and state updates
class QueryObserver<TData, TError> {
  final QueryCache _cache;
  QueryOptions<TData, TError> _options;
  Query<TData, TError>? _currentQuery;
  Timer? _refetchIntervalTimer;
  StreamSubscription? _cacheSubscription;

  final StreamController<QueryResult<TData, TError>> _resultController =
      StreamController<QueryResult<TData, TError>>.broadcast();

  QueryResult<TData, TError>? _currentResult;

  QueryObserver({
    required QueryCache cache,
    required QueryOptions<TData, TError> options,
  })  : _cache = cache,
        _options = options;

  /// Stream of query results
  Stream<QueryResult<TData, TError>> get stream => _resultController.stream;

  /// Current result
  QueryResult<TData, TError>? get currentResult => _currentResult;

  /// Current options
  QueryOptions<TData, TError> get options => _options;

  /// Update options
  void setOptions(QueryOptions<TData, TError> options) {
    final prevOptions = _options;
    _options = options;

    // If query key changed, we need to switch queries
    if (_currentQuery != null &&
        _currentQuery!.queryHash != options.queryKey.toString()) {
      _unsubscribe();
      _subscribe();
    }

    // Update refetch interval if changed
    if (prevOptions.refetchInterval != options.refetchInterval) {
      _updateRefetchInterval();
    }
  }

  /// Subscribe to a query
  void _subscribe() {
    _currentQuery = _cache.build<TData, TError>(options: _options);
    _currentQuery!.addObserver(_onQueryUpdate);
    _updateResult();
    _updateRefetchInterval();
  }

  /// Unsubscribe from current query
  void _unsubscribe() {
    _currentQuery?.removeObserver(_onQueryUpdate);
    _currentQuery = null;
    _stopRefetchInterval();
  }

  /// Handle query state update - receives dynamic to avoid web type issues
  void _onQueryUpdate(dynamic state) {
    _updateResult();
  }

  /// Update the current result
  void _updateResult() {
    if (_currentQuery == null) return;

    _currentResult = QueryResult.fromQuery<TData, TError>(_currentQuery!);
    _resultController.add(_currentResult!);
  }

  /// Start the observer
  Future<QueryResult<TData, TError>> start() async {
    _subscribe();

    // Determine if we should fetch on mount
    final hasData = _currentQuery!.state.hasData;
    final isStale = _currentQuery!.isStale;
    final refetchOnMount = _options.refetchOnMount;

    FluQueryLogger.debug('QueryObserver.start: key=${_options.queryKey}, '
        'hasData=$hasData, isStale=$isStale, refetchOnMount=$refetchOnMount, '
        'enabled=${_options.enabled}');

    // Fetch conditions:
    // 1. Always fetch if no data exists
    // 2. If refetchOnMount is true (default), fetch if data is stale
    // 3. If refetchOnMount is false, don't fetch even if stale (use cached data)
    final shouldFetch =
        _options.enabled && (!hasData || (isStale && refetchOnMount));

    FluQueryLogger.debug('QueryObserver.start: shouldFetch=$shouldFetch');

    if (shouldFetch) {
      try {
        await _currentQuery!.fetch(queryFn: _options.queryFn);
      } catch (_) {
        // Error is captured in state
      }
      _updateResult();
    }

    return _currentResult!;
  }

  /// Fetch data - returns Object? to avoid web type issues
  Future<Object?> fetch({bool forceRefetch = false}) async {
    if (_currentQuery == null) {
      _subscribe();
    }
    return await _currentQuery!.fetch(
      queryFn: _options.queryFn,
      forceRefetch: forceRefetch,
    );
  }

  /// Refetch data
  Future<Object?> refetch() => fetch(forceRefetch: true);

  /// Update refetch interval
  void _updateRefetchInterval() {
    _stopRefetchInterval();

    if (_options.refetchInterval != null && _options.enabled) {
      _refetchIntervalTimer = Timer.periodic(
        _options.refetchInterval!,
        (_) => refetch(),
      );
    }
  }

  /// Stop refetch interval
  void _stopRefetchInterval() {
    _refetchIntervalTimer?.cancel();
    _refetchIntervalTimer = null;
  }

  /// Destroy the observer
  void destroy() {
    _unsubscribe();
    _cacheSubscription?.cancel();
    _resultController.close();
  }
}
