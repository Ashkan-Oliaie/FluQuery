import '../../common/common.dart';
import '../../query/query.dart';
import '../service_key.dart';

/// Manages QueryStore ownership for automatic cleanup.
///
/// Tracks which service owns which stores, ensuring stores are
/// automatically disposed when their owning service is disposed.
class StoreOwnership {
  final QueryCache _queryCache;

  StoreOwnership(this._queryCache);

  /// Stores owned by each service (keyed by ServiceKey for proper named service support)
  final Map<ServiceKey, List<QueryStore>> _serviceStores = {};

  /// Resolution context - tracks the root service initiating resolution
  ServiceKey? _resolutionRoot;

  /// Get/set the resolution root for store ownership attribution.
  ServiceKey? get resolutionRoot => _resolutionRoot;
  set resolutionRoot(ServiceKey? value) => _resolutionRoot = value;

  /// Register a store as owned by a service.
  ///
  /// [ownerKey] is determined by:
  /// 1. The resolution root (first service in dependency chain)
  /// 2. The currently initializing service (from LifecycleManager)
  void registerStore(
      ServiceKey? ownerKey, QueryStore store, QueryKey queryKey) {
    if (ownerKey != null) {
      _serviceStores.putIfAbsent(ownerKey, () => []).add(store);
      FluQueryLogger.debug('Store $queryKey assigned to service $ownerKey');
    } else {
      FluQueryLogger.warn(
        'Store $queryKey created outside service context - will not be auto-disposed',
      );
    }
  }

  /// Dispose all stores owned by a service and remove their queries from cache.
  void disposeStoresFor(ServiceKey serviceKey) {
    final stores = _serviceStores.remove(serviceKey);
    if (stores != null) {
      for (final store in stores) {
        // Remove the query from cache first
        final query = _queryCache.getUntyped(store.queryKey);
        if (query != null) {
          _queryCache.remove(query);
        }
        // Then dispose the store
        store.dispose();
      }
      FluQueryLogger.debug('Disposed ${stores.length} stores for $serviceKey');
    }
  }

  /// Dispose all tracked stores and remove from cache.
  void disposeAll() {
    for (final stores in _serviceStores.values) {
      for (final store in stores) {
        final query = _queryCache.getUntyped(store.queryKey);
        if (query != null) {
          _queryCache.remove(query);
        }
        store.dispose();
      }
    }
    _serviceStores.clear();
  }

  /// Clear all tracking.
  void clear() {
    _serviceStores.clear();
    _resolutionRoot = null;
  }

  /// Get stores owned by a service (for testing).
  List<QueryStore> getStoresFor(ServiceKey serviceKey) =>
      List.unmodifiable(_serviceStores[serviceKey] ?? []);

  /// Get all stores grouped by owner (for devtools).
  Map<ServiceKey, List<QueryStore>> get storesByOwner =>
      Map.unmodifiable(_serviceStores);
}
