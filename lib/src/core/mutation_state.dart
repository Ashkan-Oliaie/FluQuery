import 'types.dart';

/// Immutable state of a mutation
/// Uses Object? internally to avoid web runtime generic cast issues
class MutationState<TData, TError, TVariables, TContext> {
  /// Internal storage - uses Object? to avoid web runtime type validation
  final Object? _data;
  final Object? _error;
  final Object? _variables;
  final Object? _context;

  final MutationStatus status;
  final DateTime? submittedAt;
  final int failureCount;
  final Object? failureReason;
  final bool isPaused;

  const MutationState({
    Object? data,
    Object? error,
    this.status = MutationStatus.idle,
    Object? variables,
    Object? context,
    this.submittedAt,
    this.failureCount = 0,
    this.failureReason,
    this.isPaused = false,
  })  : _data = data,
        _error = error,
        _variables = variables,
        _context = context;

  /// Raw data access - no type checking
  Object? get rawData => _data;

  /// Raw error access - no type checking
  Object? get rawError => _error;

  /// Raw variables access - no type checking
  Object? get rawVariables => _variables;

  /// Raw context access - no type checking
  Object? get rawContext => _context;

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

  /// Get variables - returns as TVariables? using dynamic
  TVariables? get variables {
    if (_variables == null) return null;
    final dynamic v = _variables;
    return v;
  }

  /// Get context - returns as TContext? using dynamic
  TContext? get context {
    if (_context == null) return null;
    final dynamic c = _context;
    return c;
  }

  /// Whether the mutation is idle
  bool get isIdle => status == MutationStatus.idle;

  /// Whether the mutation is pending
  bool get isPending => status == MutationStatus.pending;

  /// Whether the mutation has an error
  bool get isError => status == MutationStatus.error;

  /// Whether the mutation was successful
  bool get isSuccess => status == MutationStatus.success;

  /// Whether there is data available
  bool get hasData => _data != null;

  /// Whether there is an error
  bool get hasError => _error != null;

  /// Copy with new values - uses Object? to avoid web type issues
  MutationState<TData, TError, TVariables, TContext> copyWith({
    Object? data,
    Object? error,
    MutationStatus? status,
    Object? variables,
    Object? context,
    DateTime? submittedAt,
    int? failureCount,
    Object? failureReason,
    bool? isPaused,
    bool clearData = false,
    bool clearError = false,
  }) {
    return MutationState<TData, TError, TVariables, TContext>(
      data: clearData ? null : (data ?? _data),
      error: clearError ? null : (error ?? _error),
      status: status ?? this.status,
      variables: variables ?? _variables,
      context: context ?? _context,
      submittedAt: submittedAt ?? this.submittedAt,
      failureCount: failureCount ?? this.failureCount,
      failureReason: failureReason ?? this.failureReason,
      isPaused: isPaused ?? this.isPaused,
    );
  }

  /// Create with success - takes Object? to avoid web type issues
  MutationState<TData, TError, TVariables, TContext> withSuccess(
      Object? newData) {
    return MutationState<TData, TError, TVariables, TContext>(
      data: newData,
      error: null,
      status: MutationStatus.success,
      variables: _variables,
      context: _context,
      submittedAt: submittedAt,
      failureCount: 0,
      failureReason: null,
      isPaused: false,
    );
  }

  /// Create with error - takes Object? to avoid web type issues
  MutationState<TData, TError, TVariables, TContext> withError(
      Object? newError) {
    return MutationState<TData, TError, TVariables, TContext>(
      data: _data,
      error: newError,
      status: MutationStatus.error,
      variables: _variables,
      context: _context,
      submittedAt: submittedAt,
      failureCount: failureCount + 1,
      failureReason: newError,
      isPaused: isPaused,
    );
  }

  /// Create initial state - can't use const because it loses generic types on web
  factory MutationState.initial() =>
      MutationState<TData, TError, TVariables, TContext>();

  @override
  String toString() =>
      'MutationState(status: $status, data: $_data, error: $_error)';
}
