import 'types.dart';

/// Immutable state of a query
/// Uses Object? internally to avoid web runtime generic cast issues
class QueryState<TData, TError> {
  /// Internal storage - uses Object? to avoid web runtime type validation
  final Object? _data;
  final Object? _error;

  final int dataUpdateCount;
  final DateTime? dataUpdatedAt;
  final int errorUpdateCount;
  final DateTime? errorUpdatedAt;
  final int fetchFailureCount;
  final Object? fetchFailureReason;
  final QueryStatus status;
  final FetchStatus fetchStatus;
  final bool isInvalidated;

  const QueryState({
    Object? data,
    this.dataUpdateCount = 0,
    this.dataUpdatedAt,
    Object? error,
    this.errorUpdateCount = 0,
    this.errorUpdatedAt,
    this.fetchFailureCount = 0,
    this.fetchFailureReason,
    this.status = QueryStatus.pending,
    this.fetchStatus = FetchStatus.idle,
    this.isInvalidated = false,
  })  : _data = data,
        _error = error;

  /// Raw data access - no type checking, used internally to avoid web type issues
  Object? get rawData => _data;

  /// Raw error access - no type checking, used internally to avoid web type issues
  Object? get rawError => _error;

  /// Get data - returns as TData? using dynamic to avoid web cast issues
  TData? get data {
    if (_data == null) return null;
    final dynamic d = _data;
    return d;
  }

  /// Get error - returns as TError? using dynamic to avoid web cast issues
  TError? get error {
    if (_error == null) return null;
    final dynamic e = _error;
    return e;
  }

  /// Whether the query is currently fetching
  bool get isFetching => fetchStatus == FetchStatus.fetching;

  /// Whether the query is paused (e.g., offline)
  bool get isPaused => fetchStatus == FetchStatus.paused;

  /// Whether the query is pending (initial load)
  bool get isPending => status == QueryStatus.pending;

  /// Whether the query has an error
  bool get isError => status == QueryStatus.error;

  /// Whether the query was successful
  bool get isSuccess => status == QueryStatus.success;

  /// Whether the query is loading (pending and fetching)
  bool get isLoading => isPending && isFetching;

  /// Whether the query is loading an error (refetching after error)
  bool get isLoadingError => isError && isFetching;

  /// Whether the query is refetching
  bool get isRefetching => isSuccess && isFetching;

  /// Whether the query is refreshing (success or error and fetching)
  bool get isRefreshing => isFetching && !isLoading;

  /// Whether there is data available
  bool get hasData => _data != null;

  /// Whether there is an error
  bool get hasError => _error != null;

  /// Copy with new data - takes Object? to avoid web type issues
  QueryState<TData, TError> withData(Object? newData) {
    return QueryState<TData, TError>(
      data: newData,
      dataUpdateCount: dataUpdateCount,
      dataUpdatedAt: dataUpdatedAt,
      error: _error,
      errorUpdateCount: errorUpdateCount,
      errorUpdatedAt: errorUpdatedAt,
      fetchFailureCount: fetchFailureCount,
      fetchFailureReason: fetchFailureReason,
      status: status,
      fetchStatus: fetchStatus,
      isInvalidated: isInvalidated,
    );
  }

  /// Copy with status changes only
  QueryState<TData, TError> copyWith({
    int? dataUpdateCount,
    DateTime? dataUpdatedAt,
    int? errorUpdateCount,
    DateTime? errorUpdatedAt,
    int? fetchFailureCount,
    Object? fetchFailureReason,
    QueryStatus? status,
    FetchStatus? fetchStatus,
    bool? isInvalidated,
    bool clearData = false,
    bool clearError = false,
  }) {
    return QueryState<TData, TError>(
      data: clearData ? null : _data,
      dataUpdateCount: dataUpdateCount ?? this.dataUpdateCount,
      dataUpdatedAt: dataUpdatedAt ?? this.dataUpdatedAt,
      error: clearError ? null : _error,
      errorUpdateCount: errorUpdateCount ?? this.errorUpdateCount,
      errorUpdatedAt: errorUpdatedAt ?? this.errorUpdatedAt,
      fetchFailureCount: fetchFailureCount ?? this.fetchFailureCount,
      fetchFailureReason: fetchFailureReason ?? this.fetchFailureReason,
      status: status ?? this.status,
      fetchStatus: fetchStatus ?? this.fetchStatus,
      isInvalidated: isInvalidated ?? this.isInvalidated,
    );
  }

  /// Create a new state with updated data - takes Object? to avoid web type issues
  QueryState<TData, TError> withSuccess(Object? newData,
      {DateTime? updatedAt}) {
    return QueryState<TData, TError>(
      data: newData,
      dataUpdateCount: dataUpdateCount + 1,
      dataUpdatedAt: updatedAt ?? DateTime.now(),
      error: null,
      errorUpdateCount: errorUpdateCount,
      errorUpdatedAt: errorUpdatedAt,
      fetchFailureCount: 0,
      fetchFailureReason: null,
      status: QueryStatus.success,
      fetchStatus: FetchStatus.idle,
      isInvalidated: false,
    );
  }

  /// Create a new state with error - takes Object? to avoid web type issues
  QueryState<TData, TError> withError(Object? newError, {Object? reason}) {
    return QueryState<TData, TError>(
      data: _data,
      dataUpdateCount: dataUpdateCount,
      dataUpdatedAt: dataUpdatedAt,
      error: newError,
      errorUpdateCount: errorUpdateCount + 1,
      errorUpdatedAt: DateTime.now(),
      fetchFailureCount: fetchFailureCount + 1,
      fetchFailureReason: reason ?? newError,
      status: QueryStatus.error,
      fetchStatus: FetchStatus.idle,
      isInvalidated: isInvalidated,
    );
  }

  /// Create initial state - can't use const because it loses generic types on web
  factory QueryState.initial() => QueryState<TData, TError>();

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is QueryState &&
          runtimeType == other.runtimeType &&
          _data == other._data &&
          dataUpdateCount == other.dataUpdateCount &&
          dataUpdatedAt == other.dataUpdatedAt &&
          _error == other._error &&
          errorUpdateCount == other.errorUpdateCount &&
          errorUpdatedAt == other.errorUpdatedAt &&
          fetchFailureCount == other.fetchFailureCount &&
          status == other.status &&
          fetchStatus == other.fetchStatus &&
          isInvalidated == other.isInvalidated;

  @override
  int get hashCode => Object.hash(
        _data,
        dataUpdateCount,
        dataUpdatedAt,
        _error,
        errorUpdateCount,
        errorUpdatedAt,
        fetchFailureCount,
        status,
        fetchStatus,
        isInvalidated,
      );

  @override
  String toString() =>
      'QueryState(status: $status, fetchStatus: $fetchStatus, data: $_data, error: $_error)';
}
