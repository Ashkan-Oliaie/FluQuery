import 'dart:async';
import 'package:flutter_hooks/flutter_hooks.dart';
import '../core/types.dart';
import '../core/query_options.dart';
import '../core/query_observer.dart';
import '../widgets/query_client_provider.dart';

/// Result type for useQuery hook
typedef UseQueryResult<TData, TError> = QueryResult<TData, TError>;

/// Hook for fetching and caching data
/// 
/// [TData] - The type of data returned by queryFn
/// [TError] - The type of error
/// 
/// Use [useQuerySelect] if you need to transform data with a select function.
QueryResult<TData, TError> useQuery<TData, TError>({
  required QueryKey queryKey,
  required QueryFn<TData> queryFn,
  StaleTime staleTime = StaleTime.zero,
  GcTime gcTime = GcTime.defaultTime,
  bool enabled = true,
  Duration? refetchInterval,
  bool refetchOnWindowFocus = true,
  bool refetchOnReconnect = true,
  bool refetchOnMount = true,
  int retry = 3,
  RetryDelayFn retryDelay = defaultRetryDelay,
  TData? placeholderData,
  TData? initialData,
  DateTime? initialDataUpdatedAt,
  /// Keep the previous data visible while fetching new data
  /// Great for paginated UIs where you want smooth transitions
  bool keepPreviousData = false,
}) {
  final context = useContext();
  final client = QueryClientProvider.of(context);

  // Use Object? to avoid web generic type issues with useState
  final resultState = useState<Object?>(null);
  
  // Keep track of previous successful data for keepPreviousData
  final previousDataRef = useRef<TData?>(null);
  
  // Track previous query key for keepPreviousData
  final previousQueryKeyRef = useRef<String?>(null);
  
  // Track if we have a result
  QueryResult<TData, TError>? getCurrentResult() {
    final current = resultState.value;
    if (current == null) return null;
    // Dynamic cast to avoid web type issues
    final dynamic d = current;
    return d;
  }

  // Create options
  final options = useMemoized(
    () => QueryOptions<TData, TError>(
      queryKey: queryKey,
      queryFn: queryFn,
      staleTime: staleTime,
      gcTime: gcTime,
      enabled: enabled,
      refetchInterval: refetchInterval,
      refetchOnWindowFocus: refetchOnWindowFocus,
      refetchOnReconnect: refetchOnReconnect,
      refetchOnMount: refetchOnMount,
      retry: retry,
      retryDelay: retryDelay,
      placeholderData: placeholderData != null
          ? PlaceholderValue(placeholderData)
          : null,
      initialData: initialData,
      initialDataUpdatedAt: initialDataUpdatedAt,
    ),
    [queryKey.toString(), enabled, staleTime, retry],
  );

  // Observer reference
  final observerRef = useRef<QueryObserver<TData, TError>?>(null);

  // Transform result and handle keepPreviousData
  QueryResult<TData, TError> transformResult(QueryResult<TData, TError> result) {
    TData? data = result.data;
    
    if (data != null) {
      // Store for keepPreviousData
      previousDataRef.value = data;
    } else if (keepPreviousData && 
               result.isFetching && 
               previousDataRef.value != null) {
      // Use previous data while fetching
      data = previousDataRef.value;
    }
    
    final isPrevData = keepPreviousData && 
                       result.isFetching && 
                       previousDataRef.value != null &&
                       data == previousDataRef.value &&
                       result.data == null;
    
    return QueryResult<TData, TError>(
      data: data as Object?,
      error: result.rawError,
      status: result.status,
      fetchStatus: result.fetchStatus,
      isLoading: result.isLoading && !(keepPreviousData && previousDataRef.value != null),
      isFetching: result.isFetching,
      isPending: result.isPending,
      isError: result.isError,
      isSuccess: result.isSuccess,
      isRefetching: result.isRefetching,
      isStale: result.isStale,
      isPaused: result.isPaused,
      hasData: data != null,
      dataUpdatedAt: result.dataUpdatedAt,
      errorUpdatedAt: result.errorUpdatedAt,
      failureCount: result.failureCount,
      failureReason: result.failureReason,
      refetch: result.refetch,
      isPlaceholderData: result.isPlaceholderData,
      isPreviousData: isPrevData,
    );
  }

  // Setup and cleanup
  useEffect(() {
    // Check if query key changed - used for keepPreviousData
    final currentKeyStr = queryKey.toString();
    if (previousQueryKeyRef.value != null && 
        previousQueryKeyRef.value != currentKeyStr &&
        !keepPreviousData) {
      // Clear previous data if not keeping it
      previousDataRef.value = null;
    }
    previousQueryKeyRef.value = currentKeyStr;
    
    // Create observer
    final observer = QueryObserver<TData, TError>(
      cache: client.queryCache,
      options: options,
    );
    observerRef.value = observer;

    // Subscribe to stream - this updates state on every change
    final subscription = observer.stream.listen((result) {
      resultState.value = transformResult(result);
    });

    // Start fetching asynchronously
    () async {
      try {
        final result = await observer.start();
        resultState.value = transformResult(result);
      } catch (_) {
        // Error is captured in observer's currentResult
        if (observer.currentResult != null) {
          resultState.value = transformResult(observer.currentResult!);
        }
      }
    }();

    return () {
      subscription.cancel();
      observer.destroy();
      observerRef.value = null;
    };
  }, [options, client.queryCache]);

  // Build refetch function
  Future<TData> refetch() async {
    final observer = observerRef.value;
    if (observer == null) {
      throw StateError('Observer not initialized');
    }
    final result = await observer.fetch(forceRefetch: true);
    final dynamic d = result;
    return d;
  }

  // Return current result or loading state
  final currentResult = getCurrentResult();
  if (currentResult != null) {
    return currentResult;
  }
  
  // Loading state - use previous data if keepPreviousData is enabled
  if (keepPreviousData && previousDataRef.value != null) {
    return QueryResult<TData, TError>(
      data: previousDataRef.value as Object?,
      error: null,
      status: QueryStatus.pending,
      fetchStatus: FetchStatus.fetching,
      isLoading: false, // Not loading because we have previous data
      isFetching: true,
      isPending: true,
      isError: false,
      isSuccess: false,
      isRefetching: false,
      isStale: true,
      isPaused: false,
      hasData: true,
      dataUpdatedAt: null,
      errorUpdatedAt: null,
      failureCount: 0,
      failureReason: null,
      refetch: refetch,
      isPlaceholderData: false,
      isPreviousData: true,
    );
  }
  
  return QueryResult<TData, TError>.loading(refetch: refetch);
}

/// Hook for fetching data with a select function to transform the result
/// 
/// [TData] - The type of data returned by queryFn
/// [TError] - The type of error
/// [TSelect] - The type returned after applying select function
/// 
/// Example:
/// ```dart
/// // Fetch all users but only select their names
/// final userNames = useQuerySelect<List<User>, Object, List<String>>(
///   queryKey: ['users'],
///   queryFn: (_) => fetchUsers(),
///   select: (users) => users.map((u) => u.name).toList(),
/// );
/// ```
QueryResult<TSelect, TError> useQuerySelect<TData, TError, TSelect>({
  required QueryKey queryKey,
  required QueryFn<TData> queryFn,
  required TSelect Function(TData data) select,
  StaleTime staleTime = StaleTime.zero,
  GcTime gcTime = GcTime.defaultTime,
  bool enabled = true,
  Duration? refetchInterval,
  bool refetchOnWindowFocus = true,
  bool refetchOnReconnect = true,
  bool refetchOnMount = true,
  int retry = 3,
  RetryDelayFn retryDelay = defaultRetryDelay,
  TData? placeholderData,
  TData? initialData,
  DateTime? initialDataUpdatedAt,
  bool keepPreviousData = false,
}) {
  final context = useContext();
  final client = QueryClientProvider.of(context);

  // Use Object? to avoid web generic type issues with useState
  final resultState = useState<Object?>(null);
  
  // Keep track of previous successful data for keepPreviousData
  final previousDataRef = useRef<TSelect?>(null);
  
  // Track previous query key for keepPreviousData
  final previousQueryKeyRef = useRef<String?>(null);
  
  // Track if we have a result
  QueryResult<TSelect, TError>? getCurrentResult() {
    final current = resultState.value;
    if (current == null) return null;
    final dynamic d = current;
    return d;
  }

  // Create options
  final options = useMemoized(
    () => QueryOptions<TData, TError>(
      queryKey: queryKey,
      queryFn: queryFn,
      staleTime: staleTime,
      gcTime: gcTime,
      enabled: enabled,
      refetchInterval: refetchInterval,
      refetchOnWindowFocus: refetchOnWindowFocus,
      refetchOnReconnect: refetchOnReconnect,
      refetchOnMount: refetchOnMount,
      retry: retry,
      retryDelay: retryDelay,
      placeholderData: placeholderData != null
          ? PlaceholderValue(placeholderData)
          : null,
      initialData: initialData,
      initialDataUpdatedAt: initialDataUpdatedAt,
    ),
    [queryKey.toString(), enabled, staleTime, retry],
  );

  // Observer reference
  final observerRef = useRef<QueryObserver<TData, TError>?>(null);

  // Transform result using select function
  QueryResult<TSelect, TError> transformResult(QueryResult<TData, TError> result) {
    TSelect? transformedData;
    
    if (result.data != null) {
      transformedData = select(result.data as TData);
      previousDataRef.value = transformedData;
    } else if (keepPreviousData && 
               result.isFetching && 
               previousDataRef.value != null) {
      transformedData = previousDataRef.value;
    }
    
    final isPrevData = keepPreviousData && 
                       result.isFetching && 
                       previousDataRef.value != null &&
                       transformedData == previousDataRef.value &&
                       result.data == null;
    
    return QueryResult<TSelect, TError>(
      data: transformedData as Object?,
      error: result.rawError,
      status: result.status,
      fetchStatus: result.fetchStatus,
      isLoading: result.isLoading && !(keepPreviousData && previousDataRef.value != null),
      isFetching: result.isFetching,
      isPending: result.isPending,
      isError: result.isError,
      isSuccess: result.isSuccess,
      isRefetching: result.isRefetching,
      isStale: result.isStale,
      isPaused: result.isPaused,
      hasData: transformedData != null,
      dataUpdatedAt: result.dataUpdatedAt,
      errorUpdatedAt: result.errorUpdatedAt,
      failureCount: result.failureCount,
      failureReason: result.failureReason,
      refetch: () async {
        final r = await result.refetch();
        return select(r);
      },
      isPlaceholderData: result.isPlaceholderData,
      isPreviousData: isPrevData,
    );
  }

  // Setup and cleanup
  useEffect(() {
    final currentKeyStr = queryKey.toString();
    if (previousQueryKeyRef.value != null && 
        previousQueryKeyRef.value != currentKeyStr &&
        !keepPreviousData) {
      previousDataRef.value = null;
    }
    previousQueryKeyRef.value = currentKeyStr;
    
    final observer = QueryObserver<TData, TError>(
      cache: client.queryCache,
      options: options,
    );
    observerRef.value = observer;

    final subscription = observer.stream.listen((result) {
      resultState.value = transformResult(result);
    });

    () async {
      try {
        final result = await observer.start();
        resultState.value = transformResult(result);
      } catch (_) {
        if (observer.currentResult != null) {
          resultState.value = transformResult(observer.currentResult!);
        }
      }
    }();

    return () {
      subscription.cancel();
      observer.destroy();
      observerRef.value = null;
    };
  }, [options, client.queryCache]);

  // Build refetch function
  Future<TSelect> refetch() async {
    final observer = observerRef.value;
    if (observer == null) {
      throw StateError('Observer not initialized');
    }
    final result = await observer.fetch(forceRefetch: true);
    final dynamic d = result;
    return select(d);
  }

  final currentResult = getCurrentResult();
  if (currentResult != null) {
    return currentResult;
  }
  
  if (keepPreviousData && previousDataRef.value != null) {
    return QueryResult<TSelect, TError>(
      data: previousDataRef.value as Object?,
      error: null,
      status: QueryStatus.pending,
      fetchStatus: FetchStatus.fetching,
      isLoading: false,
      isFetching: true,
      isPending: true,
      isError: false,
      isSuccess: false,
      isRefetching: false,
      isStale: true,
      isPaused: false,
      hasData: true,
      dataUpdatedAt: null,
      errorUpdatedAt: null,
      failureCount: 0,
      failureReason: null,
      refetch: refetch,
      isPlaceholderData: false,
      isPreviousData: true,
    );
  }
  
  return QueryResult<TSelect, TError>.loading(refetch: refetch);
}

/// Simplified useQuery hook for basic use cases
QueryResult<TData, Object> useSimpleQuery<TData>({
  required QueryKey queryKey,
  required Future<TData> Function() queryFn,
  StaleTime staleTime = StaleTime.zero,
  bool enabled = true,
  bool keepPreviousData = false,
}) {
  return useQuery<TData, Object>(
    queryKey: queryKey,
    queryFn: (_) => queryFn(),
    staleTime: staleTime,
    enabled: enabled,
    keepPreviousData: keepPreviousData,
  );
}
