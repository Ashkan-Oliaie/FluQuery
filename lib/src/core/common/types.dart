/// Core types, typedefs, and enums for FluQuery
library;

import 'dart:async';

import 'query_key.dart';
import 'cancellation_token.dart' hide VoidCallback;

// Re-export everything
export 'query_key.dart';
export 'cancellation_token.dart';
export 'stale_time.dart';
export 'cache_time.dart';
export 'logger.dart';

/// Function type for fetching query data
typedef QueryFn<T> = FutureOr<T> Function(QueryFnContext context);

/// Function type for mutations
typedef MutationFn<TData, TVariables> = FutureOr<TData> Function(
    TVariables variables);

/// Context passed to query functions
class QueryFnContext {
  /// The query key
  final QueryKey queryKey;

  /// Page parameter for infinite queries
  final Object? pageParam;

  /// Cancellation signal
  final CancellationToken? signal;

  /// Metadata attached to the query
  final Map<String, dynamic> meta;

  const QueryFnContext({
    required this.queryKey,
    this.pageParam,
    this.signal,
    this.meta = const {},
  });
}

/// Query status enum
enum QueryStatus {
  /// Initial pending state
  pending,

  /// Error occurred
  error,

  /// Successfully fetched
  success,
}

/// Fetch status enum
enum FetchStatus {
  /// Currently fetching
  fetching,

  /// Paused (e.g., offline)
  paused,

  /// Idle, not fetching
  idle,
}

/// Mutation status enum
enum MutationStatus {
  /// Not yet triggered
  idle,

  /// Currently executing
  pending,

  /// Error occurred
  error,

  /// Successfully completed
  success,
}

/// Network mode for queries
enum NetworkMode {
  /// Always fetch from network
  online,

  /// Fetch if online, use cache if offline
  offlineFirst,

  /// Always use cache, never fetch
  always,
}

/// Refetch behavior when invalidating queries
enum RefetchType {
  /// Refetch only queries with active observers
  active,

  /// Refetch all matching queries
  all,

  /// Don't refetch, just mark as stale
  none,
}

/// Retry delay function type
typedef RetryDelayFn = Duration Function(int attemptIndex, Object error);

/// Default retry delay with exponential backoff
Duration defaultRetryDelay(int attemptIndex, Object error) {
  return Duration(milliseconds: 1000 * (1 << attemptIndex.clamp(0, 4)));
}

/// Placeholder data configuration
sealed class PlaceholderData<T> {
  const PlaceholderData();
}

/// Placeholder with a static value
class PlaceholderValue<T> extends PlaceholderData<T> {
  final T value;
  const PlaceholderValue(this.value);
}

/// Placeholder from cache
class PlaceholderFromCache<T> extends PlaceholderData<T> {
  final T? Function(QueryKey key)? selector;
  const PlaceholderFromCache([this.selector]);
}

/// Select function for transforming query data
typedef SelectFn<TData, TResult> = TResult Function(TData data);

/// Infinite query get next page param function
typedef GetNextPageParamFn<TData, TPageParam> = TPageParam? Function(
  TData lastPage,
  List<TData> allPages,
  TPageParam? lastPageParam,
  List<TPageParam?> allPageParams,
);

/// Infinite query get previous page param function
typedef GetPreviousPageParamFn<TData, TPageParam> = TPageParam? Function(
  TData firstPage,
  List<TData> allPages,
  TPageParam? firstPageParam,
  List<TPageParam?> allPageParams,
);
