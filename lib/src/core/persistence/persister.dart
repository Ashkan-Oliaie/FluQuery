import 'persisted_query.dart';

/// Abstract persister interface for storage backends
abstract class Persister {
  Future<void> init();
  Future<void> persistQuery(PersistedQuery query);
  Future<PersistedQuery?> restoreQuery(String queryHash);
  Future<List<PersistedQuery>> restoreAll();
  Future<void> removeQuery(String queryHash);
  Future<void> removeQueries(bool Function(PersistedQuery) filter);
  Future<void> clear();
  Future<void> close();
}
