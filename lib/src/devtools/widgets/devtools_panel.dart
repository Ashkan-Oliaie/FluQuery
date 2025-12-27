import 'package:flutter/material.dart';
import '../devtools_controller.dart';
import 'query_item.dart';
import 'stats_header.dart';

/// Main devtools panel showing queries, services, stores, and controls
class DevtoolsPanel extends StatelessWidget {
  final DevtoolsController controller;
  final VoidCallback onClose;

  /// Callback for dragging the header to move the panel
  final void Function(Offset delta)? onDragHeader;

  /// Whether in mobile mode (affects styling)
  final bool isMobile;

  const DevtoolsPanel({
    super.key,
    required this.controller,
    required this.onClose,
    this.onDragHeader,
    this.isMobile = false,
  });

  @override
  Widget build(BuildContext context) {
    final borderRadius = isMobile
        ? const BorderRadius.vertical(top: Radius.circular(16))
        : BorderRadius.circular(12);

    return Material(
      color: const Color(0xFF0d1117),
      borderRadius: borderRadius,
      clipBehavior: Clip.antiAlias,
      elevation: 16,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: borderRadius,
          border: Border.all(color: const Color(0xFF30363d), width: 1),
        ),
        child: ListenableBuilder(
          listenable: controller,
          builder: (context, _) => Column(
            children: [
              // Mobile drag handle
              if (isMobile)
                Container(
                  height: 20,
                  alignment: Alignment.center,
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFF6e7681),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              _Header(
                controller: controller,
                onClose: onClose,
                onDrag: onDragHeader,
                isMobile: isMobile,
              ),
              StatsHeader(stats: controller.stats),
              _TabBar(controller: controller),
              _SearchBar(controller: controller),
              Expanded(child: _buildContent()),
              _ActionBar(controller: controller),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContent() {
    switch (controller.currentTab) {
      case DevtoolsTab.queries:
        return Column(
          children: [
            _FilterChips(controller: controller),
            Expanded(child: _QueryList(controller: controller)),
          ],
        );
      case DevtoolsTab.services:
        return _ServiceList(controller: controller);
      case DevtoolsTab.stores:
        return _StoreList(controller: controller);
    }
  }
}

class _Header extends StatelessWidget {
  final DevtoolsController controller;
  final VoidCallback onClose;
  final void Function(Offset delta)? onDrag;
  final bool isMobile;

  const _Header({
    required this.controller,
    required this.onClose,
    this.onDrag,
    this.isMobile = false,
  });

  @override
  Widget build(BuildContext context) {
    // On mobile, header is not draggable (use top edge drag handle instead)
    final isDraggable = onDrag != null && !isMobile;

    return GestureDetector(
      onPanUpdate: isDraggable ? (details) => onDrag!(details.delta) : null,
      child: MouseRegion(
        cursor:
            isDraggable ? SystemMouseCursors.move : SystemMouseCursors.basic,
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: 16,
            vertical: isMobile ? 8 : 12,
          ),
          decoration: BoxDecoration(
            color: const Color(0xFF161b22),
            borderRadius: isMobile
                ? BorderRadius.zero
                : const BorderRadius.vertical(top: Radius.circular(11)),
            border: const Border(
              bottom: BorderSide(color: Color(0xFF30363d), width: 1),
            ),
          ),
          child: Row(
            children: [
              if (isDraggable) ...[
                const Icon(Icons.drag_indicator,
                    size: 16, color: Color(0xFF6e7681)),
                const SizedBox(width: 8),
              ],
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: controller.stats.fetchingQueries > 0
                      ? const Color(0xFF00d9ff)
                      : const Color(0xFF3fb950),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: (controller.stats.fetchingQueries > 0
                              ? const Color(0xFF00d9ff)
                              : const Color(0xFF3fb950))
                          .withValues(alpha: 0.5),
                      blurRadius: 6,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Text(
                isMobile ? 'Devtools' : 'FluQuery Devtools',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.3,
                ),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.refresh, size: 18),
                color: const Color(0xFF8b949e),
                onPressed: controller.refresh,
                tooltip: 'Refresh',
                visualDensity: VisualDensity.compact,
              ),
              IconButton(
                icon: const Icon(Icons.close, size: 18),
                color: const Color(0xFF8b949e),
                onPressed: onClose,
                tooltip: isMobile ? 'Close' : 'Close (Shift+D)',
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TabBar extends StatelessWidget {
  final DevtoolsController controller;

  const _TabBar({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFF30363d), width: 1)),
      ),
      child: Row(
        children: [
          _TabButton(
            label: 'Queries',
            count: controller.stats.totalQueries,
            isSelected: controller.currentTab == DevtoolsTab.queries,
            onTap: () => controller.currentTab = DevtoolsTab.queries,
          ),
          _TabButton(
            label: 'Services',
            count: controller.stats.totalServices,
            isSelected: controller.currentTab == DevtoolsTab.services,
            onTap: () => controller.currentTab = DevtoolsTab.services,
          ),
          _TabButton(
            label: 'Stores',
            count: controller.stats.totalStores,
            isSelected: controller.currentTab == DevtoolsTab.stores,
            onTap: () => controller.currentTab = DevtoolsTab.stores,
          ),
        ],
      ),
    );
  }
}

class _TabButton extends StatelessWidget {
  final String label;
  final int count;
  final bool isSelected;
  final VoidCallback onTap;

  const _TabButton({
    required this.label,
    required this.count,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color:
                    isSelected ? const Color(0xFF00d9ff) : Colors.transparent,
                width: 2,
              ),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: isSelected ? Colors.white : const Color(0xFF8b949e),
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                ),
              ),
              if (count > 0) ...[
                const SizedBox(width: 6),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? const Color(0xFF00d9ff).withValues(alpha: 0.2)
                        : const Color(0xFF30363d),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '$count',
                    style: TextStyle(
                      color: isSelected
                          ? const Color(0xFF00d9ff)
                          : const Color(0xFF8b949e),
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _SearchBar extends StatelessWidget {
  final DevtoolsController controller;

  const _SearchBar({required this.controller});

  @override
  Widget build(BuildContext context) {
    final hint = switch (controller.currentTab) {
      DevtoolsTab.queries => 'Search queries...',
      DevtoolsTab.services => 'Search services...',
      DevtoolsTab.stores => 'Search stores...',
    };

    return Padding(
      padding: const EdgeInsets.all(12),
      child: TextField(
        onChanged: (v) => controller.searchFilter = v,
        style: const TextStyle(color: Colors.white, fontSize: 13),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: Color(0xFF6e7681)),
          prefixIcon:
              const Icon(Icons.search, color: Color(0xFF6e7681), size: 18),
          isDense: true,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          filled: true,
          fillColor: const Color(0xFF21262d),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(6),
            borderSide: const BorderSide(color: Color(0xFF30363d)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(6),
            borderSide: const BorderSide(color: Color(0xFF30363d)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(6),
            borderSide: const BorderSide(color: Color(0xFF00d9ff)),
          ),
        ),
      ),
    );
  }
}

class _FilterChips extends StatelessWidget {
  final DevtoolsController controller;

  const _FilterChips({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: QueryStatusFilter.values.map((filter) {
            final isSelected = controller.statusFilter == filter;
            return Padding(
              padding: const EdgeInsets.only(right: 6),
              child: FilterChip(
                label: Text(_filterLabel(filter)),
                selected: isSelected,
                onSelected: (_) => controller.statusFilter = filter,
                labelStyle: TextStyle(
                  color: isSelected ? Colors.white : const Color(0xFF8b949e),
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
                backgroundColor: const Color(0xFF21262d),
                selectedColor: const Color(0xFF238636),
                side: BorderSide(
                  color: isSelected
                      ? const Color(0xFF238636)
                      : const Color(0xFF30363d),
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: 4),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  String _filterLabel(QueryStatusFilter filter) {
    return switch (filter) {
      QueryStatusFilter.all => 'All',
      QueryStatusFilter.fresh => 'Fresh',
      QueryStatusFilter.stale => 'Stale',
      QueryStatusFilter.fetching => 'Fetching',
      QueryStatusFilter.error => 'Error',
      QueryStatusFilter.inactive => 'Inactive',
    };
  }
}

class _QueryList extends StatelessWidget {
  final DevtoolsController controller;

  const _QueryList({required this.controller});

  @override
  Widget build(BuildContext context) {
    final queries = controller.queries;

    if (queries.isEmpty) {
      return _EmptyState(
        icon: Icons.inbox_outlined,
        message: controller.searchFilter.isNotEmpty
            ? 'No matching queries'
            : 'No queries in cache',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 4),
      itemCount: queries.length,
      itemBuilder: (context, index) {
        final query = queries[index];
        return QueryItem(
          snapshot: query,
          onRefetch: () => controller.refetchQuery(query),
          onInvalidate: () => controller.invalidateQuery(query),
          onReset: () => controller.resetQuery(query),
          onRemove: () => controller.removeQuery(query),
        );
      },
    );
  }
}

class _ServiceList extends StatelessWidget {
  final DevtoolsController controller;

  const _ServiceList({required this.controller});

  @override
  Widget build(BuildContext context) {
    final services = controller.services;

    if (services.isEmpty) {
      return _EmptyState(
        icon: Icons.settings_outlined,
        message: controller.searchFilter.isNotEmpty
            ? 'No matching services'
            : 'No services registered',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 4),
      itemCount: services.length,
      itemBuilder: (context, index) {
        final service = services[index];
        return _ServiceItem(service: service);
      },
    );
  }
}

class _ServiceItem extends StatelessWidget {
  final ServiceSnapshot service;

  const _ServiceItem({required this.service});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF161b22),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF30363d)),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: service.isInitialized
                  ? const Color(0xFF3fb950).withValues(alpha: 0.2)
                  : const Color(0xFFd29922).withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(
              Icons.settings,
              size: 16,
              color: service.isInitialized
                  ? const Color(0xFF3fb950)
                  : const Color(0xFFd29922),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        service.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          fontFamily: 'SF Mono, Menlo, Monaco, monospace',
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (service.namedAs != null) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFa371f7).withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          service.namedAs!,
                          style: const TextStyle(
                            color: Color(0xFFa371f7),
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(
                      service.isInitialized
                          ? Icons.check_circle
                          : Icons.pending,
                      size: 12,
                      color: service.isInitialized
                          ? const Color(0xFF3fb950)
                          : const Color(0xFFd29922),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      service.isInitialized ? 'Initialized' : 'Pending',
                      style: TextStyle(
                        color: service.isInitialized
                            ? const Color(0xFF3fb950)
                            : const Color(0xFFd29922),
                        fontSize: 11,
                      ),
                    ),
                    if (service.storeCount > 0) ...[
                      const SizedBox(width: 12),
                      const Icon(Icons.storage,
                          size: 12, color: Color(0xFF6e7681)),
                      const SizedBox(width: 4),
                      Text(
                        '${service.storeCount} stores',
                        style: const TextStyle(
                          color: Color(0xFF6e7681),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StoreList extends StatelessWidget {
  final DevtoolsController controller;

  const _StoreList({required this.controller});

  @override
  Widget build(BuildContext context) {
    final stores = controller.stores;

    if (stores.isEmpty) {
      return _EmptyState(
        icon: Icons.storage_outlined,
        message: controller.searchFilter.isNotEmpty
            ? 'No matching stores'
            : 'No QueryStores created',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 4),
      itemCount: stores.length,
      itemBuilder: (context, index) {
        final store = stores[index];
        return _StoreItem(store: store);
      },
    );
  }
}

class _StoreItem extends StatelessWidget {
  final StoreSnapshot store;

  const _StoreItem({required this.store});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF161b22),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF30363d)),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: store.hasData
                  ? const Color(0xFF3fb950).withValues(alpha: 0.2)
                  : const Color(0xFF6e7681).withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(
              Icons.storage,
              size: 16,
              color: store.hasData
                  ? const Color(0xFF3fb950)
                  : const Color(0xFF6e7681),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  store.queryKey,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    fontFamily: 'SF Mono, Menlo, Monaco, monospace',
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.account_tree,
                        size: 12, color: Color(0xFF6e7681)),
                    const SizedBox(width: 4),
                    Text(
                      store.ownerService,
                      style: const TextStyle(
                        color: Color(0xFF6e7681),
                        fontSize: 11,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: store.isStale
                            ? const Color(0xFFd29922).withValues(alpha: 0.2)
                            : const Color(0xFF3fb950).withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        store.isStale ? 'Stale' : 'Fresh',
                        style: TextStyle(
                          color: store.isStale
                              ? const Color(0xFFd29922)
                              : const Color(0xFF3fb950),
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    if (store.isPersisted) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFa371f7).withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.save,
                                size: 10, color: Color(0xFFa371f7)),
                            SizedBox(width: 3),
                            Text(
                              'Persisted',
                              style: TextStyle(
                                color: Color(0xFFa371f7),
                                fontSize: 10,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String message;

  const _EmptyState({required this.icon, required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 48, color: const Color(0xFF30363d)),
          const SizedBox(height: 12),
          Text(
            message,
            style: const TextStyle(color: Color(0xFF6e7681), fontSize: 13),
          ),
        ],
      ),
    );
  }
}

class _ActionBar extends StatelessWidget {
  final DevtoolsController controller;

  const _ActionBar({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: const BoxDecoration(
        color: Color(0xFF161b22),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(11)),
        border: Border(top: BorderSide(color: Color(0xFF30363d), width: 1)),
      ),
      child: Row(
        children: [
          _ActionButton(
            icon: Icons.sync,
            label: 'Refetch Stale',
            onPressed: controller.refetchStale,
          ),
          const SizedBox(width: 8),
          _ActionButton(
            icon: Icons.refresh,
            label: 'Invalidate All',
            onPressed: controller.invalidateAll,
          ),
          const SizedBox(width: 8),
          _ActionButton(
            icon: Icons.delete_outline,
            label: 'Clear Cache',
            onPressed: controller.clearCache,
            danger: true,
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  final bool danger;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.danger = false,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Material(
        color: const Color(0xFF21262d),
        borderRadius: BorderRadius.circular(6),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(6),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color:
                    danger ? const Color(0xFFf85149) : const Color(0xFF30363d),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  size: 14,
                  color: danger
                      ? const Color(0xFFf85149)
                      : const Color(0xFF8b949e),
                ),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: TextStyle(
                    color: danger
                        ? const Color(0xFFf85149)
                        : const Color(0xFF8b949e),
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
