import 'dart:async';
import 'package:flutter/widgets.dart';
import '../core/types.dart';
import '../core/query_options.dart';
import '../core/query_observer.dart';
import '../core/query_client.dart';
import 'query_client_provider.dart';

/// Builder widget for queries (alternative to hooks)
class QueryBuilder<TData, TError> extends StatefulWidget {
  /// Unique key for the query
  final QueryKey queryKey;

  /// Function to fetch data
  final QueryFn<TData> queryFn;

  /// Builder function
  final Widget Function(BuildContext context, QueryResult<TData, TError> result)
      builder;

  /// Time after which data is considered stale
  final StaleTime staleTime;

  /// How long inactive query data remains in cache before removal
  final CacheTime cacheTime;

  /// Whether the query is enabled
  final bool enabled;

  /// Polling interval
  final Duration? refetchInterval;

  /// Number of retries
  final int retry;

  /// Placeholder data
  final TData? placeholderData;

  const QueryBuilder({
    super.key,
    required this.queryKey,
    required this.queryFn,
    required this.builder,
    this.staleTime = StaleTime.zero,
    this.cacheTime = CacheTime.defaultTime,
    this.enabled = true,
    this.refetchInterval,
    this.retry = 3,
    this.placeholderData,
  });

  @override
  State<QueryBuilder<TData, TError>> createState() =>
      _QueryBuilderState<TData, TError>();
}

class _QueryBuilderState<TData, TError>
    extends State<QueryBuilder<TData, TError>> {
  late QueryClient _client;
  late QueryObserver<TData, TError> _observer;
  QueryResult<TData, TError>? _result;
  StreamSubscription? _subscription;

  @override
  void initState() {
    super.initState();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _client = QueryClientProvider.of(context);
    _setupObserver();
  }

  void _setupObserver() {
    _subscription?.cancel();

    final options = QueryOptions<TData, TError>(
      queryKey: widget.queryKey,
      queryFn: widget.queryFn,
      staleTime: widget.staleTime,
      cacheTime: widget.cacheTime,
      enabled: widget.enabled,
      refetchInterval: widget.refetchInterval,
      retry: widget.retry,
      placeholderData: widget.placeholderData != null
          ? PlaceholderValue(widget.placeholderData as TData)
          : null,
    );

    _observer = QueryObserver<TData, TError>(
      cache: _client.queryCache,
      options: options,
    );

    _subscription = _observer.stream.listen((result) {
      if (mounted) {
        setState(() => _result = result);
      }
    });

    // Start observing
    _observer.start().then((result) {
      if (mounted) {
        setState(() => _result = result);
      }
    });
  }

  @override
  void didUpdateWidget(QueryBuilder<TData, TError> oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Check if options changed
    if (widget.queryKey.toString() != oldWidget.queryKey.toString() ||
        widget.enabled != oldWidget.enabled ||
        widget.refetchInterval != oldWidget.refetchInterval) {
      _setupObserver();
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _observer.destroy();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final result = _result ??
        QueryResult<TData, TError>.loading(
          refetch: () async {
            final r = await _observer.fetch();
            final dynamic d = r;
            return d;
          },
        );
    return widget.builder(context, result);
  }
}

/// Builder widget for mutations (alternative to hooks)
class MutationBuilder<TData, TError, TVariables> extends StatefulWidget {
  /// Function to perform mutation
  final Future<TData> Function(TVariables variables) mutationFn;

  /// Builder function
  final Widget Function(
    BuildContext context,
    Future<TData> Function(TVariables) mutate,
    MutationBuilderState<TData, TError, TVariables> state,
  ) builder;

  /// Called on success
  final void Function(TData data, TVariables variables)? onSuccess;

  /// Called on error
  final void Function(TError error, TVariables variables)? onError;

  /// Called when settled
  final void Function(TData? data, TError? error, TVariables variables)?
      onSettled;

  const MutationBuilder({
    super.key,
    required this.mutationFn,
    required this.builder,
    this.onSuccess,
    this.onError,
    this.onSettled,
  });

  @override
  State<MutationBuilder<TData, TError, TVariables>> createState() =>
      _MutationBuilderState<TData, TError, TVariables>();
}

/// State for MutationBuilder
class MutationBuilderState<TData, TError, TVariables> {
  final TData? data;
  final TError? error;
  final bool isIdle;
  final bool isPending;
  final bool isError;
  final bool isSuccess;
  final TVariables? variables;

  const MutationBuilderState({
    this.data,
    this.error,
    this.isIdle = true,
    this.isPending = false,
    this.isError = false,
    this.isSuccess = false,
    this.variables,
  });

  MutationBuilderState<TData, TError, TVariables> copyWith({
    TData? data,
    TError? error,
    bool? isIdle,
    bool? isPending,
    bool? isError,
    bool? isSuccess,
    TVariables? variables,
    bool clearData = false,
    bool clearError = false,
  }) {
    return MutationBuilderState(
      data: clearData ? null : (data ?? this.data),
      error: clearError ? null : (error ?? this.error),
      isIdle: isIdle ?? this.isIdle,
      isPending: isPending ?? this.isPending,
      isError: isError ?? this.isError,
      isSuccess: isSuccess ?? this.isSuccess,
      variables: variables ?? this.variables,
    );
  }
}

class _MutationBuilderState<TData, TError, TVariables>
    extends State<MutationBuilder<TData, TError, TVariables>> {
  MutationBuilderState<TData, TError, TVariables> _state =
      const MutationBuilderState();

  Future<TData> _mutate(TVariables variables) async {
    setState(() {
      _state = _state.copyWith(
        isIdle: false,
        isPending: true,
        isError: false,
        isSuccess: false,
        variables: variables,
        clearError: true,
      );
    });

    try {
      final data = await widget.mutationFn(variables);

      setState(() {
        _state = _state.copyWith(
          data: data,
          isIdle: false,
          isPending: false,
          isError: false,
          isSuccess: true,
        );
      });

      widget.onSuccess?.call(data, variables);
      widget.onSettled?.call(data, null, variables);

      return data;
    } catch (error) {
      final typedError = error as TError;
      setState(() {
        _state = _state.copyWith(
          error: typedError,
          isIdle: false,
          isPending: false,
          isError: true,
          isSuccess: false,
        );
      });

      widget.onError?.call(typedError, variables);
      widget.onSettled?.call(null, typedError, variables);

      rethrow;
    }
  }

  @override
  Widget build(BuildContext context) {
    return widget.builder(context, _mutate, _state);
  }
}
