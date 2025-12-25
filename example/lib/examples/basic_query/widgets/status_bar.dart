import 'package:flutter/material.dart';
import '../../shared/shared.dart';

/// Status bar showing todo statistics
class StatusBar extends StatelessWidget {
  final int total;
  final int completed;
  final int pending;
  final bool isStale;
  final DateTime? dataUpdatedAt;

  const StatusBar({
    super.key,
    required this.total,
    required this.completed,
    required this.pending,
    required this.isStale,
    this.dataUpdatedAt,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accentColor = Theme.of(context).colorScheme.primary;

    return ThemedCard(
      elevated: true,
      margin: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              StatChip(label: 'Total', value: '$total', color: accentColor),
              StatChip(
                label: 'Done',
                value: '$completed',
                color: Color.lerp(accentColor, Colors.green, 0.5),
              ),
              StatChip(
                label: 'Pending',
                value: '$pending',
                color: Color.lerp(accentColor, Colors.orange, 0.5),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            isStale ? '⚠️ Data is stale' : '✅ Data is fresh',
            style: TextStyle(
              fontSize: 12,
              color: isStale ? Colors.orange : Colors.green,
            ),
          ),
          if (dataUpdatedAt != null)
            Text(
              'Updated: ${_formatTime(dataUpdatedAt!)}',
              style: TextStyle(
                fontSize: 11,
                color: isDark ? Colors.white38 : Colors.black26,
              ),
            ),
        ],
      ),
    );
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);
    if (diff.inSeconds < 60) {
      return '${diff.inSeconds}s ago';
    } else if (diff.inMinutes < 60) {
      return '${diff.inMinutes}m ago';
    } else {
      return '${time.hour}:${time.minute.toString().padLeft(2, '0')}';
    }
  }
}

