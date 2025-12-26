import 'dart:async';
import '../common/common.dart';
import 'query_impl.dart';
import 'query_state.dart';
import 'query_options.dart';
import 'query_cache.dart';

/// A persistent query store that exists independently of widget lifecycle.
///
/// Unlike `useQuery`, a `QueryStore`:
/// - Survives widget unmounts
/// - Can poll in the background indefinitely
/// - Is never garbage collected (until disposed)
/// - Can be accessed and manipulated from anywhere
///
/// Example:
/// ```dart
/// // Create a store
/// final userStore = client.createStore<User, Object>(
///   queryKey: ['user'],
///   queryFn: fetchUser,
///   refetchInterval: Duration(minutes: 1),
/// );
///
/// // Access data anywhere
/// final user = userStore.data;
///
/// // Subscribe to changes
/// final unsubscribe = userStore.subscribe((state) {
///   print('User changed: ${state.data}');
/// });
///
/// // Manipulate
/// userStore.refetch();
/// userStore.setData(newUser);
///
/// // Cleanup when done
/// userStore.dispose();
/// ```
class QueryStore<TData, TError> {
  final QueryCache _cache;
  final QueryKey queryKey;
  final QueryFn<TData> queryFn;
  final StaleTime staleTime;
  final int retry;
  final RetryDelayFn retryDelay;
  final bool refetchOnWindowFocus;
  final bool refetchOnReconnect;

  /// Current refetch interval (mutable to support setRefetchInterval)
  Duration? _refetchInterval;

  late final Query<TData, TError> _query;
  Timer? _refetchTimer;
  VoidCallback? _querySubscription;
  final StreamController<QueryState<TData, TError>> _stateController =
      StreamController<QueryState<TData, TError>>.broadcast();

  bool _isDisposed = false;

  QueryStore({
    required this.queryKey,
    required this.queryFn,
    required QueryCache cache,
    this.staleTime = StaleTime.zero,
    this.retry = 3,
    this.retryDelay = defaultRetryDelay,
    Duration? refetchInterval,
    this.refetchOnWindowFocus = true,
    this.refetchOnReconnect = true,
  })  : _cache = cache,
        _refetchInterval = refetchInterval {
    _initialize();
  }

  void _initialize() {
    final options = QueryOptions<TData, TError>(
      queryKey: queryKey,
      queryFn: queryFn,
      staleTime: staleTime,
      cacheTime: CacheTime.infinity, // Never remove stores from cache
      retry: retry,
      retryDelay: retryDelay,
      refetchOnWindowFocus: refetchOnWindowFocus,
      refetchOnReconnect: refetchOnReconnect,
    );

    _query = _cache.build<TData, TError>(options: options);

    // Subscribe to query changes
    _querySubscription = _query.subscribe((state) {
      if (!_isDisposed) {
        _stateController.add(state);
      }
    });

    // Start refetch interval if configured
    _startRefetchInterval();

    // Initial fetch - errors are stored in state, not thrown
    _query.fetch(queryFn: queryFn);

    FluQueryLogger.debug('QueryStore created: $queryKey');
  }

  /// Performs a background refetch
  void _backgroundRefetch() {
    if (_isDisposed) return;
    FluQueryLogger.debug('QueryStore refetch interval: $queryKey');
    // Errors are stored in state, not thrown
    _query.fetch(queryFn: queryFn, forceRefetch: true);
  }

  void _startRefetchInterval() {
    _refetchTimer?.cancel();
    _refetchTimer = null;
    if (_refetchInterval == null || _isDisposed) return;

    _refetchTimer =
        Timer.periodic(_refetchInterval!, (_) => _backgroundRefetch());
  }

  /// Current refetch interval
  Duration? get refetchInterval => _refetchInterval;

  /// Current query state
  QueryState<TData, TError> get state => _query.state;

  /// Current data (null if not loaded or error)
  TData? get data {
    final dynamic d = state.rawData;
    return d as TData?;
  }

  /// Current error (null if no error)
  TError? get error {
    final dynamic e = state.rawError;
    return e as TError?;
  }

  /// Whether the store is currently fetching
  bool get isFetching => state.isFetching;

  /// Whether the store is in loading state (no data yet)
  bool get isLoading => state.isLoading;

  /// Whether the store has data
  bool get hasData => state.hasData;

  /// Whether the store has an error
  bool get hasError => state.hasError;

  /// Whether the store is stale
  bool get isStale => _query.isStale;

  /// Stream of state changes
  Stream<QueryState<TData, TError>> get stream => _stateController.stream;

  /// Subscribe to state changes
  /// Returns an unsubscribe function
  VoidCallback subscribe(
      void Function(QueryState<TData, TError> state) listener) {
    final subscription = _stateController.stream.listen(listener);

    // Emit current state immediately
    listener(_query.state);

    return () => subscription.cancel();
  }

  /// Fetch data (respects stale time)
  /// Returns the data if successful, null if failed (check state.error)
  Future<TData?> fetch() async {
    if (_isDisposed) return null;

    final result = await _query.fetch(queryFn: queryFn);
    final dynamic d = result;
    return d as TData?;
  }

  /// Force refetch (ignores stale time)
  /// Returns the data if successful, null if failed (check state.error)
  Future<TData?> refetch() async {
    if (_isDisposed) return null;

    final result = await _query.fetch(queryFn: queryFn, forceRefetch: true);
    final dynamic d = result;
    return d as TData?;
  }

  /// Set data directly in cache
  void setData(TData data, {DateTime? updatedAt}) {
    if (_isDisposed) return;
    _query.setData(data, updatedAt: updatedAt);
  }

  /// Update data using a function
  void updateData(TData Function(TData? currentData) updater) {
    if (_isDisposed) return;
    final newData = updater(data);
    setData(newData);
  }

  /// Invalidate the store (marks as stale)
  void invalidate() {
    if (_isDisposed) return;
    _query.invalidate();
  }

  /// Reset the store to initial state
  void reset() {
    if (_isDisposed) return;
    _query.reset();
  }

  /// Cancel any in-flight fetch
  void cancel() {
    if (_isDisposed) return;
    _query.cancel();
  }

  /// Update the refetch interval
  void setRefetchInterval(Duration? interval) {
    _refetchInterval = interval;
    _startRefetchInterval(); // DRY: reuse existing logic
  }

  /// Stop background refetching
  void stopRefetching() {
    _refetchTimer?.cancel();
    _refetchTimer = null;
  }

  /// Resume background refetching with the configured interval
  void resumeRefetching() {
    _startRefetchInterval();
  }

  /// Whether the store has been disposed
  bool get isDisposed => _isDisposed;

  /// Dispose the store and clean up resources
  void dispose() {
    if (_isDisposed) return;

    _isDisposed = true;
    _refetchTimer?.cancel();
    _refetchTimer = null;
    _querySubscription?.call();
    _querySubscription = null;
    _stateController.close();

    // Remove the observer we added
    // Note: The query itself may still exist in cache if other observers exist
    FluQueryLogger.debug('QueryStore disposed: $queryKey');
  }
}
