import 'persisted_query.dart';
import 'persister.dart';

/// In-memory persister for testing
class InMemoryPersister implements Persister {
  final Map<String, PersistedQuery> _storage = {};

  @override
  Future<void> init() async {}

  @override
  Future<void> persistQuery(PersistedQuery query) async {
    _storage[query.queryHash] = query;
  }

  @override
  Future<PersistedQuery?> restoreQuery(String queryHash) async {
    return _storage[queryHash];
  }

  @override
  Future<List<PersistedQuery>> restoreAll() async {
    return _storage.values.toList();
  }

  @override
  Future<void> removeQuery(String queryHash) async {
    _storage.remove(queryHash);
  }

  @override
  Future<void> removeQueries(bool Function(PersistedQuery) filter) async {
    _storage.removeWhere((_, query) => filter(query));
  }

  @override
  Future<void> clear() async {
    _storage.clear();
  }

  @override
  Future<void> close() async {}
}

