import '../../common/common.dart';
import '../../query/query.dart';

/// Manages QueryStore ownership for automatic cleanup.
///
/// Tracks which service owns which stores, ensuring stores are
/// automatically disposed when their owning service is disposed.
class StoreOwnership {
  /// Stores owned by each service type
  final Map<Type, List<QueryStore>> _serviceStores = {};

  /// Resolution context - tracks the root service initiating resolution
  Type? _resolutionRoot;

  /// Get/set the resolution root for store ownership attribution.
  Type? get resolutionRoot => _resolutionRoot;
  set resolutionRoot(Type? value) => _resolutionRoot = value;

  /// Register a store as owned by a service.
  ///
  /// [ownerType] is determined by:
  /// 1. The resolution root (first service in dependency chain)
  /// 2. The currently initializing service (from LifecycleManager)
  void registerStore(Type? ownerType, QueryStore store, QueryKey queryKey) {
    if (ownerType != null) {
      _serviceStores.putIfAbsent(ownerType, () => []).add(store);
      FluQueryLogger.debug('Store $queryKey assigned to service $ownerType');
    } else {
      FluQueryLogger.warn(
        'Store $queryKey created outside service context - will not be auto-disposed',
      );
    }
  }

  /// Dispose all stores owned by a service.
  void disposeStoresFor(Type serviceType) {
    final stores = _serviceStores.remove(serviceType);
    if (stores != null) {
      for (final store in stores) {
        store.dispose();
      }
      FluQueryLogger.debug('Disposed ${stores.length} stores for $serviceType');
    }
  }

  /// Dispose all tracked stores.
  void disposeAll() {
    for (final stores in _serviceStores.values) {
      for (final store in stores) {
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
  List<QueryStore> getStoresFor(Type serviceType) =>
      List.unmodifiable(_serviceStores[serviceType] ?? []);
}
