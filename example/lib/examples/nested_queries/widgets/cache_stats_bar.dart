import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:fluquery/fluquery.dart';

/// Shows cache statistics for nested queries
class CacheStatsBar extends HookWidget {
  final QueryClient client;

  const CacheStatsBar({super.key, required this.client});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accentColor = Theme.of(context).colorScheme.primary;

    // Force rebuild periodically to update stats
    final updateTrigger = useState(0);
    useEffect(() {
      final timer = Stream.periodic(const Duration(seconds: 2)).listen((_) {
        updateTrigger.value++;
      });
      return timer.cancel;
    }, []);

    final cachedDetails = client.queryCache.queries
        .where((q) => q.queryKey.toString().contains('todo-details'))
        .length;
    final cachedSubtasks = client.queryCache.queries
        .where((q) => q.queryKey.toString().contains('subtasks'))
        .length;

    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          _StatChip(
            icon: Icons.article,
            label: 'Details',
            value: '$cachedDetails',
            color: accentColor,
          ),
          const SizedBox(width: 12),
          _StatChip(
            icon: Icons.checklist,
            label: 'Subtasks',
            value: '$cachedSubtasks',
            color: Color.lerp(accentColor, const Color(0xFF10B981), 0.5)!,
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF2A2A3E) : Colors.grey.shade100,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.info_outline,
                  size: 14,
                  color: isDark ? Colors.white54 : Colors.black38,
                ),
                const SizedBox(width: 6),
                Text(
                  'No refetch on mutations!',
                  style: TextStyle(
                    color: isDark ? Colors.white54 : Colors.black38,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _StatChip({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withAlpha(26),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withAlpha(77)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Text(
            '$label: $value cached',
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
