import 'package:flutter_hooks/flutter_hooks.dart';
import '../core/common/common.dart';
import '../core/query/query.dart';
import '../widgets/query_client_provider.dart';

/// Result type for useInfiniteQuery hook
class UseInfiniteQueryResult<TData, TError, TPageParam> {
  final List<TData> pages;
  final List<TPageParam?> pageParams;
  final TError? error;
  final bool isLoading;
  final bool isFetching;
  final bool isPending;
  final bool isError;
  final bool isSuccess;
  final bool hasNextPage;
  final bool hasPreviousPage;
  final bool isFetchingNextPage;
  final bool isFetchingPreviousPage;
  final Future<List<TData>> Function() fetchNextPage;
  final Future<List<TData>> Function() fetchPreviousPage;
  final Future<List<TData>> Function() refetch;
  final bool hasData;
  final DateTime? dataUpdatedAt;

  const UseInfiniteQueryResult({
    required this.pages,
    required this.pageParams,
    required this.error,
    required this.isLoading,
    required this.isFetching,
    required this.isPending,
    required this.isError,
    required this.isSuccess,
    required this.hasNextPage,
    required this.hasPreviousPage,
    required this.isFetchingNextPage,
    required this.isFetchingPreviousPage,
    required this.fetchNextPage,
    required this.fetchPreviousPage,
    required this.refetch,
    required this.hasData,
    required this.dataUpdatedAt,
  });

  /// Get all data flattened
  List<T> flatMap<T>(T Function(TData page) mapper) {
    return pages.map(mapper).toList();
  }

  factory UseInfiniteQueryResult.fromState(
    InfiniteQueryState<TData, TError, TPageParam> state, {
    required Future<List<TData>> Function() fetchNextPage,
    required Future<List<TData>> Function() fetchPreviousPage,
    required Future<List<TData>> Function() refetch,
  }) {
    return UseInfiniteQueryResult(
      pages: state.pages,
      pageParams: state.pageParams,
      error: state.error,
      isLoading: state.isLoading,
      isFetching: state.isFetching,
      isPending: state.isPending,
      isError: state.isError,
      isSuccess: state.isSuccess,
      hasNextPage: state.hasNextPage,
      hasPreviousPage: state.hasPreviousPage,
      isFetchingNextPage: state.isFetchingNextPage,
      isFetchingPreviousPage: state.isFetchingPreviousPage,
      fetchNextPage: fetchNextPage,
      fetchPreviousPage: fetchPreviousPage,
      refetch: refetch,
      hasData: state.hasData,
      dataUpdatedAt: state.dataUpdatedAt,
    );
  }

  factory UseInfiniteQueryResult.loading({
    required Future<List<TData>> Function() fetchNextPage,
    required Future<List<TData>> Function() fetchPreviousPage,
    required Future<List<TData>> Function() refetch,
  }) {
    return UseInfiniteQueryResult(
      pages: [],
      pageParams: [],
      error: null,
      isLoading: true,
      isFetching: true,
      isPending: true,
      isError: false,
      isSuccess: false,
      hasNextPage: false,
      hasPreviousPage: false,
      isFetchingNextPage: false,
      isFetchingPreviousPage: false,
      fetchNextPage: fetchNextPage,
      fetchPreviousPage: fetchPreviousPage,
      refetch: refetch,
      hasData: false,
      dataUpdatedAt: null,
    );
  }
}

/// Hook for infinite/paginated queries
UseInfiniteQueryResult<TData, TError, TPageParam>
    useInfiniteQuery<TData, TError, TPageParam>({
  required QueryKey queryKey,
  required Future<TData> Function(QueryFnContext context) queryFn,
  required TPageParam? initialPageParam,
  required GetNextPageParamFn<TData, TPageParam>? getNextPageParam,
  GetPreviousPageParamFn<TData, TPageParam>? getPreviousPageParam,
  StaleTime staleTime = StaleTime.zero,
  CacheTime cacheTime = CacheTime.defaultTime,
  bool enabled = true,
  bool refetchOnWindowFocus = true,
  bool refetchOnReconnect = true,
  int retry = 3,
  RetryDelayFn retryDelay = defaultRetryDelay,
  int? maxPages,
}) {
  final context = useContext();
  final client = QueryClientProvider.of(context);

  // Create a stable hash of the query key
  final queryKeyHash = QueryKeyUtils.hashKey(queryKey);

  // Get or create infinite query from cache (pure lookup, no option updates)
  final query = useMemoized(
    () => client.getOrCreateInfiniteQuery<TData, TError, TPageParam>(
      queryKey: queryKey,
      initialPageParam: initialPageParam,
    ),
    [queryKeyHash],
  );

  // Create current options (these may change each render)
  final currentOptions = InfiniteQueryOptions<TData, TError, TPageParam>(
    queryKey: queryKey,
    queryFn: queryFn,
    initialPageParam: initialPageParam,
    getNextPageParam: getNextPageParam,
    getPreviousPageParam: getPreviousPageParam,
    staleTime: staleTime,
    cacheTime: cacheTime,
    enabled: enabled,
    refetchOnWindowFocus: refetchOnWindowFocus,
    refetchOnReconnect: refetchOnReconnect,
    retry: retry,
    retryDelay: retryDelay,
    maxPages: maxPages,
  );

  // Update options on the query (for when we actually fetch)
  query.setOptions(currentOptions);

  // State - track query state changes
  final stateNotifier = useState(query.state);

  // Track if hook is mounted
  final isMountedRef = useRef(true);
  useEffect(() {
    isMountedRef.value = true;
    return () {
      isMountedRef.value = false;
    };
  }, const []);

  // Use a ref to track the previous query hash
  final prevHashRef = useRef<String?>(null);

  // When query key changes, immediately show cached data
  if (prevHashRef.value != queryKeyHash) {
    prevHashRef.value = queryKeyHash;
    // Synchronously update state to show cached data
    stateNotifier.value = query.state;
  }

  // Subscribe to query updates and handle fetching
  useEffect(() {
    void listener(InfiniteQueryState<TData, TError, TPageParam> state) {
      if (isMountedRef.value) {
        stateNotifier.value = state;
      }
    }

    query.addObserver(listener);

    // Always sync state first
    if (isMountedRef.value) {
      stateNotifier.value = query.state;
    }

    // Only fetch if enabled AND (no data OR stale)
    if (enabled && (!query.state.hasData || query.isStale)) {
      query.fetch();
    }

    return () => query.removeObserver(listener);
  }, [query, enabled]);

  return UseInfiniteQueryResult.fromState(
    stateNotifier.value,
    fetchNextPage: query.fetchNextPage,
    fetchPreviousPage: query.fetchPreviousPage,
    refetch: query.fetch,
  );
}
