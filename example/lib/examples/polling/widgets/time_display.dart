import 'package:flutter/material.dart';
import 'package:fluquery/fluquery.dart';
import '../../../api/api_client.dart';
import '../../shared/shared.dart';

/// Display widget for server time
class TimeDisplay extends StatelessWidget {
  final QueryResult<ServerTime, Object> query;
  final bool isPolling;
  final int fetchCount;

  const TimeDisplay({
    super.key,
    required this.query,
    required this.isPolling,
    required this.fetchCount,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accentColor = Theme.of(context).colorScheme.primary;

    return ThemedCard(
      elevated: true,
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _StatusIndicator(isPolling: isPolling),
          const SizedBox(height: 24),
          if (query.isLoading && query.data == null)
            LoadingIndicator()
          else if (query.isError)
            Text(
              'Error: ${query.error}',
              style: const TextStyle(color: Colors.red),
            )
          else if (query.data != null) ...[
            Text(
              _formatTime(query.data!.time),
              style: TextStyle(
                fontSize: 48,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black87,
                fontFamily: 'monospace',
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _formatDate(query.data!.time),
              style: TextStyle(
                fontSize: 16,
                color: isDark ? Colors.white54 : Colors.black45,
              ),
            ),
          ],
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: accentColor.withAlpha(20),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              'Fetched $fetchCount times',
              style: TextStyle(fontSize: 12, color: accentColor),
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime time) {
    return '${time.hour.toString().padLeft(2, '0')}:'
        '${time.minute.toString().padLeft(2, '0')}:'
        '${time.second.toString().padLeft(2, '0')}';
  }

  String _formatDate(DateTime time) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    return '${months[time.month - 1]} ${time.day}, ${time.year}';
  }
}

class _StatusIndicator extends StatelessWidget {
  final bool isPolling;

  const _StatusIndicator({required this.isPolling});

  @override
  Widget build(BuildContext context) {
    final accentColor = Theme.of(context).colorScheme.primary;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isPolling ? accentColor : Colors.grey,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          isPolling ? 'LIVE' : 'PAUSED',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: isPolling ? accentColor : Colors.grey,
            letterSpacing: 2,
          ),
        ),
      ],
    );
  }
}
