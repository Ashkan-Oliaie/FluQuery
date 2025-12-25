import 'types.dart';

/// Options for configuring a query
class QueryOptions<TData, TError> {
  /// Unique key for the query
  final QueryKey queryKey;

  /// Function to fetch the data
  final QueryFn<TData>? queryFn;

  /// Time after which data is considered stale
  final StaleTime staleTime;

  /// Time after which inactive query data is garbage collected
  final GcTime gcTime;

  /// Whether to refetch on window focus
  final bool refetchOnWindowFocus;

  /// Whether to refetch on reconnect
  final bool refetchOnReconnect;

  /// Whether to refetch on mount
  final bool refetchOnMount;

  /// Polling interval (null = no polling)
  final Duration? refetchInterval;

  /// Whether to poll in background
  final bool refetchIntervalInBackground;

  /// Number of retries on failure
  final int retry;

  /// Delay between retries
  final RetryDelayFn retryDelay;

  /// Network mode
  final NetworkMode networkMode;

  /// Whether the query is enabled
  final bool enabled;

  /// Placeholder data while loading
  final PlaceholderData<TData>? placeholderData;

  /// Initial data
  final TData? initialData;

  /// Time when initial data was last updated
  final DateTime? initialDataUpdatedAt;

  /// Metadata attached to the query
  final Map<String, dynamic> meta;

  /// Behavior for structural sharing
  final bool structuralSharing;

  /// Throw errors instead of returning them
  final bool throwOnError;

  const QueryOptions({
    required this.queryKey,
    this.queryFn,
    this.staleTime = StaleTime.zero,
    this.gcTime = GcTime.defaultTime,
    this.refetchOnWindowFocus = true,
    this.refetchOnReconnect = true,
    this.refetchOnMount = true,
    this.refetchInterval,
    this.refetchIntervalInBackground = false,
    this.retry = 3,
    this.retryDelay = defaultRetryDelay,
    this.networkMode = NetworkMode.online,
    this.enabled = true,
    this.placeholderData,
    this.initialData,
    this.initialDataUpdatedAt,
    this.meta = const {},
    this.structuralSharing = true,
    this.throwOnError = false,
  });

  /// Copy with new values
  QueryOptions<TData, TError> copyWith({
    QueryKey? queryKey,
    QueryFn<TData>? queryFn,
    StaleTime? staleTime,
    GcTime? gcTime,
    bool? refetchOnWindowFocus,
    bool? refetchOnReconnect,
    bool? refetchOnMount,
    Duration? refetchInterval,
    bool? refetchIntervalInBackground,
    int? retry,
    RetryDelayFn? retryDelay,
    NetworkMode? networkMode,
    bool? enabled,
    PlaceholderData<TData>? placeholderData,
    TData? initialData,
    DateTime? initialDataUpdatedAt,
    Map<String, dynamic>? meta,
    bool? structuralSharing,
    bool? throwOnError,
  }) {
    return QueryOptions<TData, TError>(
      queryKey: queryKey ?? this.queryKey,
      queryFn: queryFn ?? this.queryFn,
      staleTime: staleTime ?? this.staleTime,
      gcTime: gcTime ?? this.gcTime,
      refetchOnWindowFocus: refetchOnWindowFocus ?? this.refetchOnWindowFocus,
      refetchOnReconnect: refetchOnReconnect ?? this.refetchOnReconnect,
      refetchOnMount: refetchOnMount ?? this.refetchOnMount,
      refetchInterval: refetchInterval ?? this.refetchInterval,
      refetchIntervalInBackground:
          refetchIntervalInBackground ?? this.refetchIntervalInBackground,
      retry: retry ?? this.retry,
      retryDelay: retryDelay ?? this.retryDelay,
      networkMode: networkMode ?? this.networkMode,
      enabled: enabled ?? this.enabled,
      placeholderData: placeholderData ?? this.placeholderData,
      initialData: initialData ?? this.initialData,
      initialDataUpdatedAt: initialDataUpdatedAt ?? this.initialDataUpdatedAt,
      meta: meta ?? this.meta,
      structuralSharing: structuralSharing ?? this.structuralSharing,
      throwOnError: throwOnError ?? this.throwOnError,
    );
  }
}

/// Default query options factory
class DefaultQueryOptions {
  StaleTime staleTime;
  GcTime gcTime;
  bool refetchOnWindowFocus;
  bool refetchOnReconnect;
  bool refetchOnMount;
  int retry;
  RetryDelayFn retryDelay;
  NetworkMode networkMode;
  bool structuralSharing;
  bool throwOnError;

  DefaultQueryOptions({
    this.staleTime = StaleTime.zero,
    this.gcTime = GcTime.defaultTime,
    this.refetchOnWindowFocus = true,
    this.refetchOnReconnect = true,
    this.refetchOnMount = true,
    this.retry = 3,
    this.retryDelay = defaultRetryDelay,
    this.networkMode = NetworkMode.online,
    this.structuralSharing = true,
    this.throwOnError = false,
  });

  /// Apply defaults to query options
  QueryOptions<TData, TError> apply<TData, TError>(
      QueryOptions<TData, TError> options) {
    return QueryOptions<TData, TError>(
      queryKey: options.queryKey,
      queryFn: options.queryFn,
      staleTime: options.staleTime,
      gcTime: options.gcTime,
      refetchOnWindowFocus: options.refetchOnWindowFocus,
      refetchOnReconnect: options.refetchOnReconnect,
      refetchOnMount: options.refetchOnMount,
      refetchInterval: options.refetchInterval,
      refetchIntervalInBackground: options.refetchIntervalInBackground,
      retry: options.retry,
      retryDelay: options.retryDelay,
      networkMode: options.networkMode,
      enabled: options.enabled,
      placeholderData: options.placeholderData,
      initialData: options.initialData,
      initialDataUpdatedAt: options.initialDataUpdatedAt,
      meta: options.meta,
      structuralSharing: options.structuralSharing,
      throwOnError: options.throwOnError,
    );
  }
}
