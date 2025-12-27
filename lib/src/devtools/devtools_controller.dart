import 'dart:async';
import 'package:flutter/foundation.dart';
import '../core/common/common.dart';
import '../core/query_client.dart';
import '../core/query/query.dart';
import '../core/mutation/mutation.dart';
import '../core/service/service.dart';
import '../core/service/service_key.dart';

/// Snapshot of a query's state for devtools display
class QuerySnapshot {
  final QueryKey queryKey;
  final String queryHash;
  final QueryStatus status;
  final FetchStatus fetchStatus;
  final bool isStale;
  final bool hasData;
  final bool hasError;
  final int observerCount;
  final DateTime? dataUpdatedAt;
  final int fetchFailureCount;
  final Object? error;
  final Object? data;
  final bool isPersisted;

  QuerySnapshot({
    required this.queryKey,
    required this.queryHash,
    required this.status,
    required this.fetchStatus,
    required this.isStale,
    required this.hasData,
    required this.hasError,
    required this.observerCount,
    this.dataUpdatedAt,
    this.fetchFailureCount = 0,
    this.error,
    this.data,
    this.isPersisted = false,
  });

  factory QuerySnapshot.fromQuery(Query query, {bool isPersisted = false}) {
    return QuerySnapshot(
      queryKey: query.queryKey,
      queryHash: query.queryHash,
      status: query.state.status,
      fetchStatus: query.state.fetchStatus,
      isStale: query.isStale,
      hasData: query.state.hasData,
      hasError: query.state.hasError,
      observerCount: query.observerCount,
      dataUpdatedAt: query.state.dataUpdatedAt,
      fetchFailureCount: query.state.fetchFailureCount,
      error: query.state.rawError,
      data: query.state.rawData,
      isPersisted: isPersisted,
    );
  }

  /// Human-readable age since last update
  String get age {
    if (dataUpdatedAt == null) return 'never';
    final diff = DateTime.now().difference(dataUpdatedAt!);
    if (diff.inSeconds < 60) return '${diff.inSeconds}s ago';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  /// Display-friendly query key
  String get displayKey {
    return queryKey.map((e) => e.toString()).join(' / ');
  }
}

/// Snapshot of a mutation's state
class MutationSnapshot {
  final String mutationKey;
  final MutationStatus status;
  final bool isPending;
  final Object? error;
  final DateTime? submittedAt;

  MutationSnapshot({
    required this.mutationKey,
    required this.status,
    required this.isPending,
    this.error,
    this.submittedAt,
  });

  factory MutationSnapshot.fromMutation(Mutation mutation) {
    return MutationSnapshot(
      mutationKey: mutation.hashCode.toString(),
      status: mutation.state.status,
      isPending: mutation.state.isPending,
      error: mutation.state.rawError,
      submittedAt: mutation.state.submittedAt,
    );
  }
}

/// Snapshot of a service's state for devtools display
class ServiceSnapshot {
  final String name;
  final Type type;
  final bool isInitialized;
  final int storeCount;
  final String? namedAs;

  ServiceSnapshot({
    required this.name,
    required this.type,
    required this.isInitialized,
    required this.storeCount,
    this.namedAs,
  });

  factory ServiceSnapshot.fromService(
    Service service, {
    int storeCount = 0,
    String? namedAs,
  }) {
    return ServiceSnapshot(
      name: service.runtimeType.toString(),
      type: service.runtimeType,
      isInitialized: service.isInitialized,
      storeCount: storeCount,
      namedAs: namedAs,
    );
  }
}

/// Snapshot of a QueryStore for devtools display
class StoreSnapshot {
  final String queryKey;
  final String ownerService;
  final bool hasData;
  final bool isStale;
  final bool isPersisted;

  StoreSnapshot({
    required this.queryKey,
    required this.ownerService,
    required this.hasData,
    required this.isStale,
    required this.isPersisted,
  });
}

/// Aggregate statistics for devtools header
class DevtoolsStats {
  final int totalQueries;
  final int fetchingQueries;
  final int staleQueries;
  final int errorQueries;
  final int activeQueries;
  final int pendingMutations;
  final int persistedQueries;
  final int totalServices;
  final int totalStores;

  const DevtoolsStats({
    this.totalQueries = 0,
    this.fetchingQueries = 0,
    this.staleQueries = 0,
    this.errorQueries = 0,
    this.activeQueries = 0,
    this.pendingMutations = 0,
    this.persistedQueries = 0,
    this.totalServices = 0,
    this.totalStores = 0,
  });
}

/// Controller that aggregates query/mutation/service data for devtools display.
///
/// Subscribes to QueryCache events and provides real-time updates.
class DevtoolsController extends ChangeNotifier {
  final QueryClient client;

  StreamSubscription? _cacheSubscription;
  Timer? _refreshTimer;

  List<QuerySnapshot> _queries = [];
  List<MutationSnapshot> _mutations = [];
  List<ServiceSnapshot> _services = [];
  List<StoreSnapshot> _stores = [];
  DevtoolsStats _stats = const DevtoolsStats();

  /// Filter for query list
  String _searchFilter = '';
  QueryStatusFilter _statusFilter = QueryStatusFilter.all;

  /// Current tab (queries, services, stores)
  DevtoolsTab _currentTab = DevtoolsTab.queries;

  DevtoolsController(this.client) {
    _initialize();
  }

  void _initialize() {
    // Subscribe to cache events
    _cacheSubscription = client.queryCache.events.listen((_) => refresh());

    // Periodic refresh for age/stale updates
    _refreshTimer =
        Timer.periodic(const Duration(seconds: 1), (_) => refresh());

    // Initial load
    refresh();
  }

  /// Current tab
  DevtoolsTab get currentTab => _currentTab;
  set currentTab(DevtoolsTab value) {
    _currentTab = value;
    notifyListeners();
  }

  /// All query snapshots (filtered)
  List<QuerySnapshot> get queries {
    var result = _queries;

    // Apply search filter
    if (_searchFilter.isNotEmpty) {
      final lower = _searchFilter.toLowerCase();
      result = result
          .where((q) => q.displayKey.toLowerCase().contains(lower))
          .toList();
    }

    // Apply status filter
    switch (_statusFilter) {
      case QueryStatusFilter.all:
        break;
      case QueryStatusFilter.fresh:
        result = result.where((q) => !q.isStale && q.hasData).toList();
      case QueryStatusFilter.stale:
        result = result.where((q) => q.isStale).toList();
      case QueryStatusFilter.fetching:
        result =
            result.where((q) => q.fetchStatus == FetchStatus.fetching).toList();
      case QueryStatusFilter.error:
        result = result.where((q) => q.hasError).toList();
      case QueryStatusFilter.inactive:
        result = result.where((q) => q.observerCount == 0).toList();
    }

    return result;
  }

  /// All mutation snapshots
  List<MutationSnapshot> get mutations => _mutations;

  /// All service snapshots (filtered by search)
  List<ServiceSnapshot> get services {
    if (_searchFilter.isEmpty) return _services;
    final lower = _searchFilter.toLowerCase();
    return _services
        .where((s) =>
            s.name.toLowerCase().contains(lower) ||
            (s.namedAs?.toLowerCase().contains(lower) ?? false))
        .toList();
  }

  /// All store snapshots (filtered by search)
  List<StoreSnapshot> get stores {
    if (_searchFilter.isEmpty) return _stores;
    final lower = _searchFilter.toLowerCase();
    return _stores
        .where((s) =>
            s.queryKey.toLowerCase().contains(lower) ||
            s.ownerService.toLowerCase().contains(lower))
        .toList();
  }

  /// Aggregate stats
  DevtoolsStats get stats => _stats;

  /// Current search filter
  String get searchFilter => _searchFilter;
  set searchFilter(String value) {
    _searchFilter = value;
    notifyListeners();
  }

  /// Current status filter
  QueryStatusFilter get statusFilter => _statusFilter;
  set statusFilter(QueryStatusFilter value) {
    _statusFilter = value;
    notifyListeners();
  }

  /// Refresh all data from cache
  void refresh() {
    final allQueries = client.queryCache.queries.toList();
    final allMutations = client.mutationCache.mutations.toList();

    // Check which queries have persistence configured
    // Use hasPersistence which checks all observer options
    _queries = allQueries.map((q) {
      return QuerySnapshot.fromQuery(q, isPersisted: q.hasPersistence);
    }).toList();
    _mutations = allMutations.map(MutationSnapshot.fromMutation).toList();

    // Collect services and stores
    _refreshServicesAndStores();

    // Calculate stats
    final persistedCount = _queries.where((q) => q.isPersisted).length;
    _stats = DevtoolsStats(
      totalQueries: allQueries.length,
      fetchingQueries: allQueries.where((q) => q.isFetching).length,
      staleQueries: allQueries.where((q) => q.isStale).length,
      errorQueries: allQueries.where((q) => q.state.hasError).length,
      activeQueries: allQueries.where((q) => q.hasObservers).length,
      pendingMutations: allMutations.where((m) => m.state.isPending).length,
      persistedQueries: persistedCount,
      totalServices: _services.length,
      totalStores: _stores.length,
    );

    notifyListeners();
  }

  void _refreshServicesAndStores() {
    final container = client.services;
    if (container == null) {
      _services = [];
      _stores = [];
      return;
    }

    final storesByOwner = container.storesByOwner;

    // Build service snapshots
    _services = [];
    for (final service in container.instances) {
      final serviceKey = ServiceKey(service.runtimeType);
      final ownerStores = storesByOwner[serviceKey] ?? [];
      _services.add(ServiceSnapshot.fromService(
        service,
        storeCount: ownerStores.length,
      ));
    }

    // Add named services
    for (final typeEntry in container.namedInstances.entries) {
      for (final nameEntry in typeEntry.value.entries) {
        final serviceKey = ServiceKey(typeEntry.key, nameEntry.key);
        final ownerStores = storesByOwner[serviceKey] ?? [];
        _services.add(ServiceSnapshot.fromService(
          nameEntry.value,
          storeCount: ownerStores.length,
          namedAs: nameEntry.key,
        ));
      }
    }

    // Build store snapshots
    _stores = [];
    for (final entry in storesByOwner.entries) {
      for (final store in entry.value) {
        _stores.add(StoreSnapshot(
          queryKey: store.queryKey.join(' / '),
          ownerService: entry.key.toString(),
          hasData: store.hasData,
          isStale: store.isStale,
          isPersisted: store.persist != null,
        ));
      }
    }
  }

  // ============================================================
  // ACTIONS
  // ============================================================

  /// Refetch a specific query (force fetch regardless of stale time)
  Future<void> refetchQuery(QuerySnapshot snapshot) async {
    final query = client.queryCache.getByHash(snapshot.queryHash);
    if (query != null) {
      await query.fetch(forceRefetch: true);
    }
  }

  /// Invalidate a specific query (mark stale, refetch if has observers)
  ///
  /// This is the TanStack Query behavior:
  /// - Mark as stale immediately
  /// - If query has active observers, refetch automatically
  /// - If no observers, will refetch on next access
  Future<void> invalidateQuery(QuerySnapshot snapshot) async {
    final query = client.queryCache.getByHash(snapshot.queryHash);
    if (query != null) {
      query.invalidate();
      // Refetch if has observers (active query)
      if (query.hasObservers) {
        await query.fetch(forceRefetch: true);
      }
    }
  }

  /// Reset a specific query to initial pending state
  ///
  /// ⚠️ This clears all data and returns query to loading state.
  /// Components subscribed to this query will show loading UI.
  /// Use this to force a "fresh start" for a query.
  void resetQuery(QuerySnapshot snapshot) {
    final query = client.queryCache.getByHash(snapshot.queryHash);
    query?.reset();
  }

  /// Remove a query from cache completely
  ///
  /// ⚠️ This removes the query entry entirely.
  /// Components using useQuery will trigger a new fetch.
  /// Components with local state may show stale data until remounted.
  void removeQuery(QuerySnapshot snapshot) {
    final query = client.queryCache.getByHash(snapshot.queryHash);
    if (query != null) {
      client.queryCache.remove(query);
    }
  }

  /// Reset a service
  Future<void> resetService(ServiceSnapshot snapshot) async {
    final container = client.services;
    if (container == null) return;

    // Need to call reset dynamically based on type
    // This is a simplified approach - in practice you might need runtime type dispatch
    FluQueryLogger.info('Devtools: Reset service ${snapshot.name}');
  }

  /// Invalidate all queries (marks stale + refetches active ones)
  Future<void> invalidateAll() async {
    await client.invalidateQueries();
  }

  /// Refetch all stale queries that have observers
  Future<void> refetchStale() async {
    await client.refetchQueries(stale: true);
  }

  /// Clear entire cache (removes all queries and mutations)
  ///
  /// ⚠️ Destructive action - all cached data is lost.
  void clearCache() {
    client.clear();
  }

  @override
  void dispose() {
    _cacheSubscription?.cancel();
    _refreshTimer?.cancel();
    super.dispose();
  }
}

/// Filter options for query list
enum QueryStatusFilter {
  all,
  fresh,
  stale,
  fetching,
  error,
  inactive,
}

/// Tabs for the devtools panel
enum DevtoolsTab {
  queries,
  services,
  stores,
}
