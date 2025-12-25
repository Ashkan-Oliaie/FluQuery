import 'dart:async';

/// Query key type - can be a string or list of dynamic values
typedef QueryKey = List<dynamic>;

/// Function type for fetching query data
typedef QueryFn<T> = FutureOr<T> Function(QueryFnContext context);

/// Function type for mutations
typedef MutationFn<TData, TVariables> = FutureOr<TData> Function(
    TVariables variables);

/// Context passed to query functions
class QueryFnContext {
  final QueryKey queryKey;
  final Object? pageParam;
  final CancellationToken? signal;
  final Map<String, dynamic> meta;

  const QueryFnContext({
    required this.queryKey,
    this.pageParam,
    this.signal,
    this.meta = const {},
  });
}

/// Cancellation token for aborting requests
class CancellationToken {
  bool _isCancelled = false;
  final List<VoidCallback> _listeners = [];

  bool get isCancelled => _isCancelled;

  void cancel() {
    _isCancelled = true;
    for (final listener in _listeners) {
      listener();
    }
    _listeners.clear();
  }

  void addListener(VoidCallback listener) {
    if (_isCancelled) {
      listener();
    } else {
      _listeners.add(listener);
    }
  }

  void removeListener(VoidCallback listener) {
    _listeners.remove(listener);
  }
}

typedef VoidCallback = void Function();

/// Query status enum
enum QueryStatus {
  pending,
  error,
  success,
}

/// Fetch status enum
enum FetchStatus {
  fetching,
  paused,
  idle,
}

/// Mutation status enum
enum MutationStatus {
  idle,
  pending,
  error,
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

/// Retry delay function type
typedef RetryDelayFn = Duration Function(int attemptIndex, Object error);

/// Default retry delay with exponential backoff
Duration defaultRetryDelay(int attemptIndex, Object error) {
  return Duration(milliseconds: 1000 * (1 << attemptIndex.clamp(0, 4)));
}

/// Stale time configuration
class StaleTime {
  final Duration duration;

  const StaleTime(this.duration);

  static const StaleTime zero = StaleTime(Duration.zero);
  static const StaleTime infinity = StaleTime(Duration(days: 365 * 100));

  bool isStale(DateTime dataUpdatedAt) {
    if (this == infinity) return false;
    return DateTime.now().difference(dataUpdatedAt) > duration;
  }
}

/// Garbage collection time configuration
class GcTime {
  final Duration duration;

  const GcTime(this.duration);

  static const GcTime defaultTime = GcTime(Duration(minutes: 5));
  static const GcTime infinity = GcTime(Duration(days: 365 * 100));
}

/// Placeholder data configuration
sealed class PlaceholderData<T> {
  const PlaceholderData();
}

class PlaceholderValue<T> extends PlaceholderData<T> {
  final T value;
  const PlaceholderValue(this.value);
}

class PlaceholderFromCache<T> extends PlaceholderData<T> {
  final T? Function(QueryKey key)? selector;
  const PlaceholderFromCache([this.selector]);
}

/// Select function for transforming query data
typedef SelectFn<TData, TResult> = TResult Function(TData data);

/// Infinite query page param function
typedef GetNextPageParamFn<TData, TPageParam> = TPageParam? Function(
  TData lastPage,
  List<TData> allPages,
  TPageParam? lastPageParam,
  List<TPageParam?> allPageParams,
);

typedef GetPreviousPageParamFn<TData, TPageParam> = TPageParam? Function(
  TData firstPage,
  List<TData> allPages,
  TPageParam? firstPageParam,
  List<TPageParam?> allPageParams,
);
