import '../common/common.dart';
import '../query/query.dart';
import 'persisted_query.dart';
import 'persister.dart';
import 'persist_options.dart';
import 'serializers.dart';

/// Manages query persistence - hydration, serialization, and storage.
///
/// This class is responsible for:
/// - Hydrating cache from persistent storage on app startup
/// - Persisting query data when queries succeed
/// - Deserializing hydrated data when queries are accessed
/// - Managing persistence options registration (first-wins strategy)
class PersistenceManager {
  final Persister _persister;
  final QueryCache _queryCache;

  /// Track which queries have persistence enabled and their serializers.
  /// Uses first-wins strategy: first observer to register persistence options
  /// determines the serializer used for that query key.
  final Map<String, PersistOptions> _persistOptions = {};

  /// Track how many observers are using persistence for each query.
  /// When count drops to 0, we keep options but remove from counts.
  final Map<String, int> _persistObserverCounts = {};

  bool _isHydrated = false;

  PersistenceManager({
    required Persister persister,
    required QueryCache queryCache,
  })  : _persister = persister,
        _queryCache = queryCache;

  /// Whether the cache has been hydrated from persistence
  bool get isHydrated => _isHydrated;

  /// The underlying persister
  Persister get persister => _persister;

  /// Get registered persist options for a query hash
  PersistOptions? getOptions(String hash) => _persistOptions[hash];

  /// Check if a query has persistence options registered
  bool hasOptions(String hash) => _persistOptions.containsKey(hash);

  // ============================================================
  // HYDRATION
  // ============================================================

  /// Hydrate the cache from persisted storage.
  ///
  /// Call this during app initialization before rendering any queries.
  /// This restores previously cached query data from disk.
  Future<void> hydrate() async {
    if (_isHydrated) {
      FluQueryLogger.debug('Cache already hydrated, skipping');
      return;
    }

    try {
      final persistedQueries = await _persister.restoreAll();
      FluQueryLogger.info(
          'Hydrating ${persistedQueries.length} queries from persistence');

      for (final persisted in persistedQueries) {
        try {
          _queryCache.hydrateQuery(
            queryKey: persisted.queryKey,
            queryHash: persisted.queryHash,
            serializedData: persisted.serializedData,
            dataUpdatedAt: persisted.dataUpdatedAt,
          );
          FluQueryLogger.debug(
              'Hydrated query: ${persisted.queryKey} (updated: ${persisted.dataUpdatedAt})');
        } catch (e) {
          FluQueryLogger.error(
              'Failed to hydrate query ${persisted.queryKey}: $e');
        }
      }

      _isHydrated = true;
      FluQueryLogger.info('Cache hydration complete');
    } catch (e) {
      FluQueryLogger.error('Failed to hydrate cache: $e');
      _isHydrated = true; // Mark as hydrated anyway to prevent blocking
    }
  }

  // ============================================================
  // REGISTRATION
  // ============================================================

  /// Register persistence options for a query.
  /// Called internally by useQuery when persist option is set.
  ///
  /// Uses first-wins strategy: the first observer to register persistence
  /// options determines the serializer and maxAge for that query key.
  void registerOptions<TData>(
    QueryKey queryKey,
    PersistOptions<TData> options,
  ) {
    final hash = QueryKeyUtils.hashKey(queryKey);

    // Increment observer count
    _persistObserverCounts[hash] = (_persistObserverCounts[hash] ?? 0) + 1;

    // First-wins: only use options from first observer
    if (_persistOptions.containsKey(hash)) {
      FluQueryLogger.debug(
          'PersistOptions already registered for $queryKey, using existing (observer count: ${_persistObserverCounts[hash]})');
      _tryDeserializeHydratedData<TData>(queryKey, _persistOptions[hash]!);
      return;
    }

    _persistOptions[hash] = options;
    FluQueryLogger.debug('Registered PersistOptions for $queryKey');

    // Try to deserialize any hydrated data
    _tryDeserializeHydratedData<TData>(queryKey, options);
  }

  /// Unregister persistence options when an observer unmounts.
  void unregisterOptions(QueryKey queryKey) {
    final hash = QueryKeyUtils.hashKey(queryKey);
    final count = _persistObserverCounts[hash] ?? 0;

    if (count <= 1) {
      _persistObserverCounts.remove(hash);
      FluQueryLogger.debug(
          'Last persistence observer unregistered for $queryKey (keeping options)');
    } else {
      _persistObserverCounts[hash] = count - 1;
      FluQueryLogger.debug(
          'Persistence observer unregistered for $queryKey (remaining: ${count - 1})');
    }
  }

  // ============================================================
  // DESERIALIZATION
  // ============================================================

  /// Try to deserialize hydrated data for a query.
  ///
  /// This method:
  /// 1. Validates maxAge - discards data older than maxAge
  /// 2. Attempts deserialization using the provided serializer
  /// 3. Handles schema changes gracefully
  void _tryDeserializeHydratedData<TData>(
    QueryKey queryKey,
    PersistOptions options,
  ) {
    final existingQuery = _queryCache.getUntyped(queryKey);
    if (existingQuery == null || existingQuery.state.rawData == null) {
      return;
    }

    final rawData = existingQuery.state.rawData;
    final dataUpdatedAt = existingQuery.state.dataUpdatedAt;

    // Validate maxAge
    if (options.maxAge != null && dataUpdatedAt != null) {
      final age = DateTime.now().difference(dataUpdatedAt);
      if (age > options.maxAge!) {
        FluQueryLogger.debug(
            'Hydrated data for $queryKey exceeded maxAge (${age.inMinutes}m > ${options.maxAge!.inMinutes}m), discarding');
        _queryCache.remove(existingQuery);
        unpersist(queryKey);
        return;
      }
    }

    // Already deserialized?
    if (rawData is TData) {
      return;
    }

    // Try to deserialize
    try {
      final deserialized = options.serializer.deserialize(rawData);
      _queryCache.setQueryData<TData>(
        queryKey,
        deserialized,
        updatedAt: dataUpdatedAt,
      );
      FluQueryLogger.debug('Deserialized hydrated data for: $queryKey');
    } catch (e, stackTrace) {
      FluQueryLogger.warn(
          'Schema mismatch for $queryKey - persisted data incompatible with current model. '
          'Discarding stale data and fetching fresh.');
      FluQueryLogger.debug('Deserialization error: $e', e, stackTrace);

      _queryCache.remove(existingQuery);

      if (options.removeOnDeserializationError) {
        unpersist(queryKey);
      }
    }
  }

  // ============================================================
  // PERSISTENCE OPERATIONS
  // ============================================================

  /// Persist a query to storage.
  Future<void> persist<TData>(
    QueryKey queryKey,
    TData data,
    DateTime? dataUpdatedAt,
  ) async {
    if (data == null) return;

    final hash = QueryKeyUtils.hashKey(queryKey);
    final options = _persistOptions[hash];
    if (options == null) return;

    try {
      final serializer = options.serializer as QueryDataSerializer<TData>;
      final serialized = serializer.serialize(data);
      final effectiveHash = options.getEffectiveHash(hash);

      final persisted = PersistedQuery(
        queryKey: queryKey,
        queryHash: effectiveHash,
        serializedData: serialized,
        dataUpdatedAt: dataUpdatedAt,
        persistedAt: DateTime.now(),
        status: 'success',
      );

      await _persister.persistQuery(persisted);
      FluQueryLogger.debug('Persisted query: $queryKey (hash: $effectiveHash)');
    } catch (e) {
      FluQueryLogger.error('Failed to persist query $queryKey: $e');
    }
  }

  /// Remove a query from persistence.
  Future<void> unpersist(QueryKey queryKey) async {
    final hash = QueryKeyUtils.hashKey(queryKey);
    final options = _persistOptions[hash];
    final effectiveHash = options?.getEffectiveHash(hash) ?? hash;

    await _persister.removeQuery(effectiveHash);
    _persistOptions.remove(hash);
    FluQueryLogger.debug('Unpersisted query: $queryKey');
  }

  /// Clear all persisted queries.
  Future<void> clear() async {
    await _persister.clear();
    _persistOptions.clear();
    FluQueryLogger.info('Cleared all persisted queries');
  }

  /// Dehydrate - get all persistable queries for manual handling.
  Future<List<PersistedQuery>> dehydrate() async {
    final results = <PersistedQuery>[];

    for (final query in _queryCache.getAll()) {
      final hash = query.queryHash;
      final options = _persistOptions[hash];
      if (options == null) continue;

      final data = query.state.rawData;
      if (data == null) continue;

      try {
        final serialized = options.serializer.serialize(data);
        results.add(PersistedQuery(
          queryKey: query.queryKey,
          queryHash: hash,
          serializedData: serialized,
          dataUpdatedAt: query.state.dataUpdatedAt,
          persistedAt: DateTime.now(),
          status: query.state.status.name,
        ));
      } catch (e) {
        FluQueryLogger.error('Failed to dehydrate query ${query.queryKey}: $e');
      }
    }

    return results;
  }

  /// Called when a query successfully fetches data.
  /// This is wired up as a callback from QueryCache.
  void onQueryDataSuccess(
    QueryKey queryKey,
    Object? data,
    DateTime? dataUpdatedAt,
  ) {
    if (data == null) return;

    final hash = QueryKeyUtils.hashKey(queryKey);
    if (!_persistOptions.containsKey(hash)) return;

    // Fire and forget
    persist(queryKey, data, dataUpdatedAt);
  }
}
