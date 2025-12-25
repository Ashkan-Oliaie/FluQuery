import 'package:flutter_hooks/flutter_hooks.dart';
import '../core/types.dart';
import '../core/mutation.dart';
import '../core/mutation_state.dart';
import '../widgets/query_client_provider.dart';

/// Result type for useMutation hook
class UseMutationResult<TData, TError, TVariables, TContext> {
  /// Internal storage using Object? to avoid web type issues
  final Object? _data;
  final Object? _error;
  final Object? _variables;
  
  final MutationStatus status;
  final bool isIdle;
  final bool isPending;
  final bool isError;
  final bool isSuccess;
  final Future<TData> Function(TVariables) mutate;
  final Future<TData> Function(TVariables) mutateAsync;
  final void Function() reset;
  final int failureCount;
  final Object? failureReason;
  final DateTime? submittedAt;

  const UseMutationResult({
    required Object? data,
    required Object? error,
    required this.status,
    required this.isIdle,
    required this.isPending,
    required this.isError,
    required this.isSuccess,
    required Object? variables,
    required this.mutate,
    required this.mutateAsync,
    required this.reset,
    required this.failureCount,
    required this.failureReason,
    required this.submittedAt,
  }) : _data = data,
       _error = error,
       _variables = variables;

  /// Get data using dynamic to avoid web cast issues
  TData? get data {
    if (_data == null) return null;
    final dynamic d = _data;
    return d;
  }

  /// Get error using dynamic to avoid web cast issues
  TError? get error {
    if (_error == null) return null;
    final dynamic e = _error;
    return e;
  }

  /// Get variables using dynamic to avoid web cast issues
  TVariables? get variables {
    if (_variables == null) return null;
    final dynamic v = _variables;
    return v;
  }

  factory UseMutationResult.fromState(
    MutationState<TData, TError, TVariables, TContext> state, {
    required Future<TData> Function(TVariables) mutate,
    required Future<TData> Function(TVariables) mutateAsync,
    required void Function() reset,
  }) {
    return UseMutationResult(
      data: state.rawData,
      error: state.rawError,
      status: state.status,
      isIdle: state.isIdle,
      isPending: state.isPending,
      isError: state.isError,
      isSuccess: state.isSuccess,
      variables: state.rawVariables,
      mutate: mutate,
      mutateAsync: mutateAsync,
      reset: reset,
      failureCount: state.failureCount,
      failureReason: state.failureReason,
      submittedAt: state.submittedAt,
    );
  }
}

/// Hook for performing mutations
UseMutationResult<TData, TError, TVariables, TContext>
    useMutation<TData, TError, TVariables, TContext>({
  required MutationFn<TData, TVariables> mutationFn,
  List<dynamic>? mutationKey,
  TContext Function(TVariables)? onMutate,
  void Function(TData data, TVariables variables, TContext? context)? onSuccess,
  void Function(TError error, TVariables variables, TContext? context)? onError,
  void Function(
          TData? data, TError? error, TVariables variables, TContext? context)?
      onSettled,
  int retry = 0,
  RetryDelayFn retryDelay = defaultRetryDelay,
  NetworkMode networkMode = NetworkMode.online,
}) {
  final context = useContext();
  final client = QueryClientProvider.of(context);

  // Create mutation
  final mutation = useMemoized(
    () => client.mutationCache
        .build<TData, TError, TVariables, TContext>(
      options: MutationOptions<TData, TError, TVariables, TContext>(
        mutationFn: mutationFn,
        mutationKey: mutationKey,
        onMutate: onMutate,
        onSuccess: onSuccess,
        onError: onError,
        onSettled: onSettled,
        retry: retry,
        retryDelay: retryDelay,
        networkMode: networkMode,
      ),
    ),
    [mutationKey?.toString()],
  );

  // State - use Object? to avoid web type issues
  final stateNotifier = useState<Object?>(mutation.state);
  
  // Helper to get typed state
  MutationState<TData, TError, TVariables, TContext> getTypedState() {
    final dynamic s = stateNotifier.value;
    if (s == null) return MutationState<TData, TError, TVariables, TContext>();
    return s;
  }

  // Subscribe to mutation
  useEffect(() {
    // Use dynamic observer to avoid web type issues
    void listener(dynamic state) {
      stateNotifier.value = state;
    }

    mutation.addObserver(listener);
    return () => mutation.removeObserver(listener);
  }, [mutation]);

  // Mutate function
  Future<TData> mutate(TVariables variables) async {
    final result = await mutation.mutate(variables);
    final dynamic d = result;
    return d;
  }

  // Reset function
  void reset() {
    mutation.reset();
  }

  return UseMutationResult.fromState(
    getTypedState(),
    mutate: mutate,
    mutateAsync: mutate,
    reset: reset,
  );
}

/// Simplified mutation hook
UseMutationResult<TData, Object, TVariables, void>
    useSimpleMutation<TData, TVariables>({
  required Future<TData> Function(TVariables) mutationFn,
  void Function(TData data, TVariables variables)? onSuccess,
  void Function(Object error, TVariables variables)? onError,
}) {
  return useMutation<TData, Object, TVariables, void>(
    mutationFn: mutationFn,
    onSuccess: onSuccess != null
        ? (data, variables, _) => onSuccess(data, variables)
        : null,
    onError: onError != null
        ? (error, variables, _) => onError(error, variables)
        : null,
  );
}
