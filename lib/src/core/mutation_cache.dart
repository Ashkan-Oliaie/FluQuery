import 'dart:async';
import 'mutation.dart';
import 'mutation_state.dart';
import 'logger.dart';

/// Event types for mutation cache
enum MutationCacheEventType {
  added,
  removed,
  updated,
}

/// Event emitted by the mutation cache
class MutationCacheEvent {
  final MutationCacheEventType type;
  final Mutation mutation;

  MutationCacheEvent({required this.type, required this.mutation});
}

/// Cache for storing and managing mutations
class MutationCache {
  final List<Mutation> _mutations = [];
  int _mutationIdCounter = 0;
  final StreamController<MutationCacheEvent> _eventController =
      StreamController<MutationCacheEvent>.broadcast();

  /// Stream of cache events
  Stream<MutationCacheEvent> get events => _eventController.stream;

  /// All mutations
  List<Mutation> get mutations => List.unmodifiable(_mutations);

  /// Number of mutations
  int get length => _mutations.length;

  /// Build a new mutation
  Mutation<TData, TError, TVariables, TContext>
      build<TData, TError, TVariables, TContext>({
    required MutationOptions<TData, TError, TVariables, TContext> options,
    MutationState<TData, TError, TVariables, TContext>? state,
  }) {
    final mutation = Mutation<TData, TError, TVariables, TContext>(
      mutationId: (_mutationIdCounter++).toString(),
      options: options,
      initialState: state,
    );

    _add(mutation);
    return mutation;
  }

  /// Add a mutation
  void _add(Mutation mutation) {
    _mutations.add(mutation);
    FluQueryLogger.debug('Mutation added to cache: ${mutation.mutationId}');

    _eventController.add(MutationCacheEvent(
      type: MutationCacheEventType.added,
      mutation: mutation,
    ));
  }

  /// Remove a mutation
  void remove(Mutation mutation) {
    _mutations.remove(mutation);
    FluQueryLogger.debug('Mutation removed from cache: ${mutation.mutationId}');

    _eventController.add(MutationCacheEvent(
      type: MutationCacheEventType.removed,
      mutation: mutation,
    ));
  }

  /// Find mutations by key
  List<Mutation> findAll({
    List<dynamic>? mutationKey,
    bool? pending,
    bool Function(Mutation mutation)? predicate,
  }) {
    return _mutations.where((mutation) {
      if (pending != null && mutation.state.isPending != pending) {
        return false;
      }
      if (predicate != null && !predicate(mutation)) {
        return false;
      }
      return true;
    }).toList();
  }

  /// Clear all mutations
  void clear() {
    for (final mutation in _mutations.toList()) {
      remove(mutation);
    }
  }

  /// Dispose the cache
  void dispose() {
    clear();
    _eventController.close();
  }
}
