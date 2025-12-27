import 'package:flutter/material.dart';
import '../../core/common/common.dart';
import '../devtools_controller.dart';
import 'status_badge.dart';

/// Individual query row in the devtools list
class QueryItem extends StatefulWidget {
  final QuerySnapshot snapshot;
  final VoidCallback onRefetch;
  final VoidCallback onInvalidate;
  final VoidCallback onReset;
  final VoidCallback onRemove;

  const QueryItem({
    super.key,
    required this.snapshot,
    required this.onRefetch,
    required this.onInvalidate,
    required this.onReset,
    required this.onRemove,
  });

  @override
  State<QueryItem> createState() => _QueryItemState();
}

class _QueryItemState extends State<QueryItem> {
  bool _isExpanded = false;
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final q = widget.snapshot;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: _isHovered ? const Color(0xFF161b22) : const Color(0xFF0d1117),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: _isExpanded ? const Color(0xFF30363d) : Colors.transparent,
          ),
        ),
        child: Column(
          children: [
            // Main row
            InkWell(
              onTap: () => setState(() => _isExpanded = !_isExpanded),
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    // Status indicator
                    StatusBadge(
                      status: q.status,
                      fetchStatus: q.fetchStatus,
                      isStale: q.isStale,
                    ),
                    const SizedBox(width: 12),

                    // Query key & info
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            q.displayKey,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              fontFamily: 'SF Mono, Menlo, Monaco, monospace',
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              _InfoChip(
                                icon: Icons.visibility_outlined,
                                label: '${q.observerCount}',
                                color: q.observerCount > 0
                                    ? const Color(0xFF3fb950)
                                    : const Color(0xFF6e7681),
                              ),
                              const SizedBox(width: 8),
                              _InfoChip(
                                icon: Icons.schedule,
                                label: q.age,
                                color: const Color(0xFF6e7681),
                              ),
                              if (q.fetchFailureCount > 0) ...[
                                const SizedBox(width: 8),
                                _InfoChip(
                                  icon: Icons.refresh,
                                  label: '${q.fetchFailureCount} retries',
                                  color: const Color(0xFFd29922),
                                ),
                              ],
                              if (q.isPersisted) ...[
                                const SizedBox(width: 8),
                                const _InfoChip(
                                  icon: Icons.save_outlined,
                                  label: 'persisted',
                                  color: Color(0xFFa371f7),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),

                    // Expand arrow
                    AnimatedRotation(
                      turns: _isExpanded ? 0.25 : 0,
                      duration: const Duration(milliseconds: 200),
                      child: Icon(
                        Icons.chevron_right,
                        color: const Color(0xFF6e7681),
                        size: 18,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Expanded content
            if (_isExpanded)
              _ExpandedContent(
                snapshot: q,
                onRefetch: widget.onRefetch,
                onInvalidate: widget.onInvalidate,
                onReset: widget.onReset,
                onRemove: widget.onRemove,
              ),
          ],
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _InfoChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: color),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 11,
          ),
        ),
      ],
    );
  }
}

class _ExpandedContent extends StatelessWidget {
  final QuerySnapshot snapshot;
  final VoidCallback onRefetch;
  final VoidCallback onInvalidate;
  final VoidCallback onReset;
  final VoidCallback onRemove;

  const _ExpandedContent({
    required this.snapshot,
    required this.onRefetch,
    required this.onInvalidate,
    required this.onReset,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Divider(color: Color(0xFF30363d), height: 16),

          // Data preview
          if (snapshot.hasData) ...[
            _SectionTitle('Data'),
            _DataPreview(data: snapshot.data),
            const SizedBox(height: 12),
          ],

          // Error info
          if (snapshot.hasError) ...[
            _SectionTitle('Error'),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFf85149).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                    color: const Color(0xFFf85149).withValues(alpha: 0.3)),
              ),
              child: Text(
                snapshot.error.toString(),
                style: const TextStyle(
                  color: Color(0xFFf85149),
                  fontSize: 11,
                  fontFamily: 'SF Mono, Menlo, Monaco, monospace',
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],

          // Details
          _SectionTitle('Details'),
          _DetailRow('Status', _statusLabel(snapshot.status)),
          _DetailRow('Fetch Status', _fetchStatusLabel(snapshot.fetchStatus)),
          _DetailRow('Is Stale', snapshot.isStale ? 'Yes' : 'No'),
          _DetailRow('Observers', '${snapshot.observerCount}'),
          _DetailRow('Persisted', snapshot.isPersisted ? 'Yes' : 'No'),
          if (snapshot.dataUpdatedAt != null)
            _DetailRow('Updated', _formatTime(snapshot.dataUpdatedAt!)),

          const SizedBox(height: 12),

          // Actions with tooltips explaining behavior
          Row(
            children: [
              _ActionButton(
                icon: Icons.refresh,
                label: 'Refetch',
                onPressed: onRefetch,
                color: const Color(0xFF00d9ff),
                tooltip: 'Force fetch new data from server',
              ),
              const SizedBox(width: 6),
              _ActionButton(
                icon: Icons.sync_disabled,
                label: 'Invalidate',
                onPressed: onInvalidate,
                color: const Color(0xFFd29922),
                tooltip: 'Mark stale + refetch if has observers',
              ),
              const SizedBox(width: 6),
              _ActionButton(
                icon: Icons.restart_alt,
                label: 'Reset',
                onPressed: onReset,
                color: const Color(0xFF8b949e),
                tooltip: 'Clear data, return to loading state',
              ),
              const SizedBox(width: 6),
              _ActionButton(
                icon: Icons.delete_outline,
                label: 'Remove',
                onPressed: onRemove,
                color: const Color(0xFFf85149),
                tooltip: 'Remove from cache entirely',
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _statusLabel(QueryStatus status) {
    return switch (status) {
      QueryStatus.pending => 'Pending',
      QueryStatus.error => 'Error',
      QueryStatus.success => 'Success',
    };
  }

  String _fetchStatusLabel(FetchStatus status) {
    return switch (status) {
      FetchStatus.idle => 'Idle',
      FetchStatus.fetching => 'Fetching',
      FetchStatus.paused => 'Paused',
    };
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);

    if (diff.inSeconds < 60) return '${diff.inSeconds}s ago';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';

    return '${time.hour.toString().padLeft(2, '0')}:'
        '${time.minute.toString().padLeft(2, '0')}:'
        '${time.second.toString().padLeft(2, '0')}';
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;

  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        text,
        style: const TextStyle(
          color: Color(0xFF8b949e),
          fontSize: 10,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;

  const _DetailRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: const TextStyle(
                color: Color(0xFF6e7681),
                fontSize: 11,
              ),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              color: Color(0xFFc9d1d9),
              fontSize: 11,
              fontFamily: 'SF Mono, Menlo, Monaco, monospace',
            ),
          ),
        ],
      ),
    );
  }
}

class _DataPreview extends StatelessWidget {
  final Object? data;

  const _DataPreview({this.data});

  @override
  Widget build(BuildContext context) {
    final preview = _formatData(data);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: const Color(0xFF161b22),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFF30363d)),
      ),
      child: Text(
        preview,
        style: const TextStyle(
          color: Color(0xFFc9d1d9),
          fontSize: 11,
          fontFamily: 'SF Mono, Menlo, Monaco, monospace',
        ),
        maxLines: 5,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  String _formatData(Object? data) {
    if (data == null) return 'null';
    if (data is String) return '"$data"';
    if (data is num || data is bool) return data.toString();
    if (data is List) {
      if (data.isEmpty) return '[]';
      return 'List (${data.length} items)';
    }
    if (data is Map) {
      if (data.isEmpty) return '{}';
      return 'Map (${data.length} keys)';
    }
    // For objects, try to show type and some info
    final str = data.toString();
    if (str.length > 200) {
      return '${str.substring(0, 200)}...';
    }
    return str;
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  final Color color;
  final String? tooltip;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onPressed,
    required this.color,
    this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    final button = Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(4),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: color.withValues(alpha: 0.5)),
          ),
          child: Column(
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(height: 2),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: 9,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );

    return Expanded(
      child:
          tooltip != null ? Tooltip(message: tooltip!, child: button) : button,
    );
  }
}
