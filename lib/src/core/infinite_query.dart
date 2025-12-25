import 'dart:async';
import 'types.dart';
import 'query_key.dart';
import 'logger.dart';

/// State for infinite query pages
class InfiniteQueryState<TData, TError, TPageParam> {
  final List<TData> pages;
  final List<TPageParam?> pageParams;
  final TError? error;
  final QueryStatus status;
  final FetchStatus fetchStatus;
  final bool isInvalidated;
  final DateTime? dataUpdatedAt;
  final bool hasNextPage;
  final bool hasPreviousPage;
  final bool isFetchingNextPage;
  final bool isFetchingPreviousPage;

  const InfiniteQueryState({
    this.pages = const [],
    this.pageParams = const [],
    this.error,
    this.status = QueryStatus.pending,
    this.fetchStatus = FetchStatus.idle,
    this.isInvalidated = false,
    this.dataUpdatedAt,
    this.hasNextPage = false,
    this.hasPreviousPage = false,
    this.isFetchingNextPage = false,
    this.isFetchingPreviousPage = false,
  });

  bool get isFetching => fetchStatus == FetchStatus.fetching;
  bool get isPending => status == QueryStatus.pending;
  bool get isError => status == QueryStatus.error;
  bool get isSuccess => status == QueryStatus.success;
  bool get isLoading => isPending && isFetching;
  bool get hasData => pages.isNotEmpty;

  InfiniteQueryState<TData, TError, TPageParam> copyWith({
    List<TData>? pages,
    List<TPageParam?>? pageParams,
    TError? error,
    QueryStatus? status,
    FetchStatus? fetchStatus,
    bool? isInvalidated,
    DateTime? dataUpdatedAt,
    bool? hasNextPage,
    bool? hasPreviousPage,
    bool? isFetchingNextPage,
    bool? isFetchingPreviousPage,
    bool clearError = false,
  }) {
    return InfiniteQueryState(
      pages: pages ?? this.pages,
      pageParams: pageParams ?? this.pageParams,
      error: clearError ? null : (error ?? this.error),
      status: status ?? this.status,
      fetchStatus: fetchStatus ?? this.fetchStatus,
      isInvalidated: isInvalidated ?? this.isInvalidated,
      dataUpdatedAt: dataUpdatedAt ?? this.dataUpdatedAt,
      hasNextPage: hasNextPage ?? this.hasNextPage,
      hasPreviousPage: hasPreviousPage ?? this.hasPreviousPage,
      isFetchingNextPage: isFetchingNextPage ?? this.isFetchingNextPage,
      isFetchingPreviousPage:
          isFetchingPreviousPage ?? this.isFetchingPreviousPage,
    );
  }
}

/// Options for infinite queries
class InfiniteQueryOptions<TData, TError, TPageParam> {
  final QueryKey queryKey;
  final Future<TData> Function(QueryFnContext context) queryFn;
  final TPageParam? initialPageParam;
  final GetNextPageParamFn<TData, TPageParam>? getNextPageParam;
  final GetPreviousPageParamFn<TData, TPageParam>? getPreviousPageParam;
  final StaleTime staleTime;
  final CacheTime cacheTime;
  final bool refetchOnWindowFocus;
  final bool refetchOnReconnect;
  final int retry;
  final RetryDelayFn retryDelay;
  final bool enabled;
  final int? maxPages;

  const InfiniteQueryOptions({
    required this.queryKey,
    required this.queryFn,
    required this.initialPageParam,
    this.getNextPageParam,
    this.getPreviousPageParam,
    this.staleTime = StaleTime.zero,
    this.cacheTime = CacheTime.defaultTime,
    this.refetchOnWindowFocus = true,
    this.refetchOnReconnect = true,
    this.retry = 3,
    this.retryDelay = defaultRetryDelay,
    this.enabled = true,
    this.maxPages,
  });
}

/// Infinite query for paginated data
class InfiniteQuery<TData, TError, TPageParam> {
  final QueryKey queryKey;
  final String queryHash;
  InfiniteQueryOptions<TData, TError, TPageParam> _options;
  InfiniteQueryState<TData, TError, TPageParam> _state;
  CancellationToken? _currentCancellationToken;

  final List<void Function(InfiniteQueryState<TData, TError, TPageParam>)>
      _observers = [];

  InfiniteQuery({
    required this.queryKey,
    required InfiniteQueryOptions<TData, TError, TPageParam> options,
    InfiniteQueryState<TData, TError, TPageParam>? initialState,
  })  : queryHash = QueryKeyUtils.hashKey(queryKey),
        _options = options,
        _state =
            initialState ?? InfiniteQueryState<TData, TError, TPageParam>();

  InfiniteQueryState<TData, TError, TPageParam> get state => _state;
  InfiniteQueryOptions<TData, TError, TPageParam> get options => _options;
  int get observerCount => _observers.length;
  bool get hasObservers => _observers.isNotEmpty;

  bool get isStale {
    if (_state.isInvalidated) return true;
    if (_state.dataUpdatedAt == null) return true;
    return _options.staleTime.isStale(_state.dataUpdatedAt!);
  }

  void setOptions(InfiniteQueryOptions<TData, TError, TPageParam> options) {
    _options = options;
  }

  void addObserver(
      void Function(InfiniteQueryState<TData, TError, TPageParam>) observer) {
    _observers.add(observer);
  }

  void removeObserver(
      void Function(InfiniteQueryState<TData, TError, TPageParam>) observer) {
    _observers.remove(observer);
  }

  void _notifyObservers() {
    for (final observer in _observers) {
      observer(_state);
    }
  }

  void _setState(InfiniteQueryState<TData, TError, TPageParam> newState) {
    _state = newState;
    _notifyObservers();
  }

  /// Fetch initial page
  Future<List<TData>> fetch() async {
    if (!_state.hasData || isStale) {
      _currentCancellationToken = CancellationToken();

      _setState(_state.copyWith(
        fetchStatus: FetchStatus.fetching,
        clearError: true,
      ));

      try {
        final context = QueryFnContext(
          queryKey: queryKey,
          pageParam: _options.initialPageParam,
          signal: _currentCancellationToken,
        );

        final data = await _options.queryFn(context);
        final nextPageParam = _options.getNextPageParam?.call(
          data,
          [data],
          _options.initialPageParam,
          [_options.initialPageParam],
        );
        final previousPageParam = _options.getPreviousPageParam?.call(
          data,
          [data],
          _options.initialPageParam,
          [_options.initialPageParam],
        );

        _setState(_state.copyWith(
          pages: [data],
          pageParams: [_options.initialPageParam],
          status: QueryStatus.success,
          fetchStatus: FetchStatus.idle,
          dataUpdatedAt: DateTime.now(),
          hasNextPage: nextPageParam != null,
          hasPreviousPage: previousPageParam != null,
          isInvalidated: false,
          clearError: true,
        ));

        FluQueryLogger.debug('Infinite query fetch success: $queryKey');
        return [data];
      } catch (error, stackTrace) {
        FluQueryLogger.error(
            'Infinite query fetch error: $queryKey', error, stackTrace);

        _setState(_state.copyWith(
          error: error as TError?,
          status: QueryStatus.error,
          fetchStatus: FetchStatus.idle,
        ));

        rethrow;
      }
    }

    return _state.pages;
  }

  /// Fetch next page
  Future<List<TData>> fetchNextPage() async {
    if (!_state.hasNextPage) return _state.pages;

    final lastPage = _state.pages.last;
    final lastPageParam = _state.pageParams.last;
    final nextPageParam = _options.getNextPageParam?.call(
      lastPage,
      _state.pages,
      lastPageParam,
      _state.pageParams,
    );

    if (nextPageParam == null) return _state.pages;

    _setState(_state.copyWith(
      fetchStatus: FetchStatus.fetching,
      isFetchingNextPage: true,
    ));

    try {
      final context = QueryFnContext(
        queryKey: queryKey,
        pageParam: nextPageParam,
        signal: _currentCancellationToken,
      );

      final data = await _options.queryFn(context);
      final newPages = [..._state.pages, data];
      final newPageParams = [..._state.pageParams, nextPageParam];

      // Check max pages
      List<TData> finalPages = newPages;
      List<TPageParam?> finalPageParams = newPageParams;
      if (_options.maxPages != null && newPages.length > _options.maxPages!) {
        finalPages = newPages.sublist(newPages.length - _options.maxPages!);
        finalPageParams =
            newPageParams.sublist(newPageParams.length - _options.maxPages!);
      }

      final newNextPageParam = _options.getNextPageParam?.call(
        data,
        finalPages,
        nextPageParam,
        finalPageParams,
      );

      _setState(_state.copyWith(
        pages: finalPages,
        pageParams: finalPageParams,
        fetchStatus: FetchStatus.idle,
        dataUpdatedAt: DateTime.now(),
        hasNextPage: newNextPageParam != null,
        isFetchingNextPage: false,
      ));

      return finalPages;
    } catch (error, stackTrace) {
      FluQueryLogger.error(
          'Infinite query fetchNextPage error: $queryKey', error, stackTrace);

      _setState(_state.copyWith(
        error: error as TError?,
        status: QueryStatus.error,
        fetchStatus: FetchStatus.idle,
        isFetchingNextPage: false,
      ));

      rethrow;
    }
  }

  /// Fetch previous page
  Future<List<TData>> fetchPreviousPage() async {
    if (!_state.hasPreviousPage) return _state.pages;

    final firstPage = _state.pages.first;
    final firstPageParam = _state.pageParams.first;
    final previousPageParam = _options.getPreviousPageParam?.call(
      firstPage,
      _state.pages,
      firstPageParam,
      _state.pageParams,
    );

    if (previousPageParam == null) return _state.pages;

    _setState(_state.copyWith(
      fetchStatus: FetchStatus.fetching,
      isFetchingPreviousPage: true,
    ));

    try {
      final context = QueryFnContext(
        queryKey: queryKey,
        pageParam: previousPageParam,
        signal: _currentCancellationToken,
      );

      final data = await _options.queryFn(context);
      final newPages = [data, ..._state.pages];
      final newPageParams = [previousPageParam, ..._state.pageParams];

      // Check max pages
      List<TData> finalPages = newPages;
      List<TPageParam?> finalPageParams = newPageParams;
      if (_options.maxPages != null && newPages.length > _options.maxPages!) {
        finalPages = newPages.sublist(0, _options.maxPages!);
        finalPageParams = newPageParams.sublist(0, _options.maxPages!);
      }

      final newPreviousPageParam = _options.getPreviousPageParam?.call(
        data,
        finalPages,
        previousPageParam,
        finalPageParams,
      );

      _setState(_state.copyWith(
        pages: finalPages,
        pageParams: finalPageParams,
        fetchStatus: FetchStatus.idle,
        dataUpdatedAt: DateTime.now(),
        hasPreviousPage: newPreviousPageParam != null,
        isFetchingPreviousPage: false,
      ));

      return finalPages;
    } catch (error, stackTrace) {
      FluQueryLogger.error('Infinite query fetchPreviousPage error: $queryKey',
          error, stackTrace);

      _setState(_state.copyWith(
        error: error as TError?,
        status: QueryStatus.error,
        fetchStatus: FetchStatus.idle,
        isFetchingPreviousPage: false,
      ));

      rethrow;
    }
  }

  /// Cancel current fetch
  void cancel() {
    _currentCancellationToken?.cancel();
    _currentCancellationToken = null;
  }

  /// Invalidate the query
  void invalidate() {
    _setState(_state.copyWith(isInvalidated: true));
  }

  /// Reset the query
  void reset() {
    cancel();
    _setState(InfiniteQueryState<TData, TError, TPageParam>());
  }
}
