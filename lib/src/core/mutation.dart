import 'dart:async';
import 'types.dart';
import 'mutation_state.dart';
import 'logger.dart';

/// Options for configuring a mutation
class MutationOptions<TData, TError, TVariables, TContext> {
  /// Function to perform the mutation
  final MutationFn<TData, TVariables> mutationFn;

  /// Called when mutation starts
  final TContext Function(TVariables variables)? onMutate;

  /// Called on mutation success
  final void Function(TData data, TVariables variables, TContext? context)?
      onSuccess;

  /// Called on mutation error
  final void Function(TError error, TVariables variables, TContext? context)?
      onError;

  /// Called when mutation settles (success or error)
  final void Function(
          TData? data, TError? error, TVariables variables, TContext? context)?
      onSettled;

  /// Number of retries on failure
  final int retry;

  /// Delay between retries
  final RetryDelayFn retryDelay;

  /// Network mode
  final NetworkMode networkMode;

  /// Custom mutation key for deduplication
  final List<dynamic>? mutationKey;

  /// Metadata
  final Map<String, dynamic> meta;

  const MutationOptions({
    required this.mutationFn,
    this.onMutate,
    this.onSuccess,
    this.onError,
    this.onSettled,
    this.retry = 0,
    this.retryDelay = defaultRetryDelay,
    this.networkMode = NetworkMode.online,
    this.mutationKey,
    this.meta = const {},
  });
}

/// A Mutation manages the state and lifecycle of a mutation operation
class Mutation<TData, TError, TVariables, TContext> {
  final String mutationId;
  MutationOptions<TData, TError, TVariables, TContext> _options;
  MutationState<TData, TError, TVariables, TContext> _state;

  // Use dynamic observer type to avoid web cast issues
  final List<void Function(dynamic)> _observers = [];

  Mutation({
    required this.mutationId,
    required MutationOptions<TData, TError, TVariables, TContext> options,
    MutationState<TData, TError, TVariables, TContext>? initialState,
  })  : _options = options,
        _state = initialState ??
            MutationState<TData, TError, TVariables, TContext>();

  /// Current state
  MutationState<TData, TError, TVariables, TContext> get state => _state;

  /// Current options
  MutationOptions<TData, TError, TVariables, TContext> get options => _options;

  /// Update options
  void setOptions(
      MutationOptions<TData, TError, TVariables, TContext> options) {
    _options = options;
  }

  /// Add an observer
  void addObserver(void Function(dynamic) observer) {
    _observers.add(observer);
  }

  /// Remove an observer
  void removeObserver(void Function(dynamic) observer) {
    _observers.remove(observer);
  }

  /// Notify all observers
  void _notifyObservers() {
    for (final observer in _observers) {
      observer(_state);
    }
  }

  /// Update state
  void _setState(MutationState<TData, TError, TVariables, TContext> newState) {
    _state = newState;
    _notifyObservers();
  }

  /// Execute the mutation - returns Object? to avoid web type issues
  Future<Object?> mutate(TVariables variables) async {
    TContext? context;

    try {
      // Call onMutate
      context = _options.onMutate?.call(variables);

      // Use Object? for variables and context to avoid web type issues
      _setState(MutationState<TData, TError, TVariables, TContext>(
        data: _state.rawData,
        error: null,
        status: MutationStatus.pending,
        variables: variables as Object?,
        context: context as Object?,
        submittedAt: DateTime.now(),
        failureCount: 0,
        failureReason: null,
        isPaused: false,
      ));

      FluQueryLogger.debug('Mutation started: $mutationId');

      // Execute with retries
      Object? data;
      int failureCount = 0;

      while (true) {
        try {
          final dynamic result = await _options.mutationFn(variables);
          data = result as Object?;
          break;
        } catch (error) {
          failureCount++;
          if (failureCount > _options.retry) {
            rethrow;
          }
          await Future.delayed(_options.retryDelay(failureCount - 1, error));
        }
      }

      _setState(_state.withSuccess(data));

      FluQueryLogger.debug('Mutation success: $mutationId');

      // Call callbacks with typed data
      final dynamic typedData = data;
      _options.onSuccess?.call(typedData, variables, context);
      _options.onSettled?.call(typedData, null, variables, context);

      return data;
    } catch (error, stackTrace) {
      FluQueryLogger.error('Mutation error: $mutationId', error, stackTrace);

      _setState(_state.withError(error));

      // Call callbacks with typed error
      final dynamic typedError = error;
      _options.onError?.call(typedError, variables, context);
      _options.onSettled?.call(null, typedError, variables, context);

      rethrow;
    }
  }

  /// Reset the mutation state
  void reset() {
    _setState(MutationState<TData, TError, TVariables, TContext>());
  }
}
