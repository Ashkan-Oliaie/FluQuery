import 'package:flutter/material.dart';
import '../devtools_controller.dart';

/// Stats bar showing aggregate query/mutation counts
class StatsHeader extends StatelessWidget {
  final DevtoolsStats stats;

  const StatsHeader({super.key, required this.stats});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: const BoxDecoration(
        color: Color(0xFF161b22),
        border: Border(
          bottom: BorderSide(color: Color(0xFF30363d), width: 1),
        ),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _StatPill(
              label: 'Total',
              value: stats.totalQueries,
              color: const Color(0xFF8b949e),
            ),
            const SizedBox(width: 6),
            _StatPill(
              label: 'Active',
              value: stats.activeQueries,
              color: const Color(0xFF3fb950),
            ),
            const SizedBox(width: 6),
            _StatPill(
              label: 'Fetching',
              value: stats.fetchingQueries,
              color: const Color(0xFF00d9ff),
              animate: stats.fetchingQueries > 0,
            ),
            const SizedBox(width: 6),
            _StatPill(
              label: 'Stale',
              value: stats.staleQueries,
              color: const Color(0xFFd29922),
            ),
            const SizedBox(width: 6),
            _StatPill(
              label: 'Error',
              value: stats.errorQueries,
              color: const Color(0xFFf85149),
            ),
            if (stats.persistedQueries > 0) ...[
              const SizedBox(width: 6),
              _StatPill(
                label: 'Persisted',
                value: stats.persistedQueries,
                color: const Color(0xFFa371f7),
                icon: Icons.save_outlined,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _StatPill extends StatelessWidget {
  final String label;
  final int value;
  final Color color;
  final bool animate;
  final IconData? icon;

  const _StatPill({
    required this.label,
    required this.value,
    required this.color,
    this.animate = false,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null)
            Icon(icon, size: 10, color: color)
          else if (animate)
            _PulsingDot(color: color)
          else
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
              ),
            ),
          const SizedBox(width: 6),
          Text(
            '$value',
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _PulsingDot extends StatefulWidget {
  final Color color;

  const _PulsingDot({required this.color});

  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    )..repeat(reverse: true);
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
        return Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(
            color:
                widget.color.withValues(alpha: 0.5 + _controller.value * 0.5),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: widget.color.withValues(alpha: _controller.value * 0.5),
                blurRadius: 4,
              ),
            ],
          ),
        );
      },
    );
  }
}
