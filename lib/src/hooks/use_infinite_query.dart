import 'package:flutter_hooks/flutter_hooks.dart';
import '../core/types.dart';
import '../core/infinite_query.dart';
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
  GcTime gcTime = GcTime.defaultTime,
  bool enabled = true,
  bool refetchOnWindowFocus = true,
  bool refetchOnReconnect = true,
  int retry = 3,
  RetryDelayFn retryDelay = defaultRetryDelay,
  int? maxPages,
}) {
  final context = useContext();
  final client = QueryClientProvider.of(context);

  // Create options
  final options = useMemoized(
    () => InfiniteQueryOptions<TData, TError, TPageParam>(
      queryKey: queryKey,
      queryFn: queryFn,
      initialPageParam: initialPageParam,
      getNextPageParam: getNextPageParam,
      getPreviousPageParam: getPreviousPageParam,
      staleTime: staleTime,
      gcTime: gcTime,
      enabled: enabled,
      refetchOnWindowFocus: refetchOnWindowFocus,
      refetchOnReconnect: refetchOnReconnect,
      retry: retry,
      retryDelay: retryDelay,
      maxPages: maxPages,
    ),
    [queryKey.toString(), enabled],
  );

  // Get or create infinite query
  final query = useMemoized(
    () => client.getInfiniteQuery(options),
    [options],
  );

  // State
  final stateNotifier = useState<InfiniteQueryState<TData, TError, TPageParam>>(
    query.state,
  );

  // Subscribe to query
  useEffect(() {
    void listener(InfiniteQueryState<TData, TError, TPageParam> state) {
      stateNotifier.value = state;
    }

    query.addObserver(listener);

    // Initial fetch if enabled
    if (enabled && (query.isStale || !query.state.hasData)) {
      query.fetch().then((_) {
        stateNotifier.value = query.state;
      }).catchError((_) {
        stateNotifier.value = query.state;
      });
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
