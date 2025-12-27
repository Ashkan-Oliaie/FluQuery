import 'package:flutter/material.dart';
import '../../core/common/common.dart';

/// Visual status indicator for a query
class StatusBadge extends StatelessWidget {
  final QueryStatus status;
  final FetchStatus fetchStatus;
  final bool isStale;

  const StatusBadge({
    super.key,
    required this.status,
    required this.fetchStatus,
    required this.isStale,
  });

  @override
  Widget build(BuildContext context) {
    final (color, icon) = _getStatusStyle();

    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: fetchStatus == FetchStatus.fetching
          ? _FetchingIndicator(color: color)
          : Icon(icon, size: 16, color: color),
    );
  }

  (Color, IconData) _getStatusStyle() {
    // Priority: fetching > error > stale > success > pending
    if (fetchStatus == FetchStatus.fetching) {
      return (const Color(0xFF00d9ff), Icons.sync);
    }

    if (status == QueryStatus.error) {
      return (const Color(0xFFf85149), Icons.error_outline);
    }

    if (isStale) {
      return (const Color(0xFFd29922), Icons.access_time);
    }

    if (status == QueryStatus.success) {
      return (const Color(0xFF3fb950), Icons.check_circle_outline);
    }

    // Pending
    return (const Color(0xFF6e7681), Icons.hourglass_empty);
  }
}

class _FetchingIndicator extends StatefulWidget {
  final Color color;

  const _FetchingIndicator({required this.color});

  @override
  State<_FetchingIndicator> createState() => _FetchingIndicatorState();
}

class _FetchingIndicatorState extends State<_FetchingIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Transform.rotate(
          angle: _controller.value * 2 * 3.14159,
          child: Icon(
            Icons.sync,
            size: 16,
            color: widget.color,
          ),
        );
      },
    );
  }
}
