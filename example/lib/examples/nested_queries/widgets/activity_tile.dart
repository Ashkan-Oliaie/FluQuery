import 'package:flutter/material.dart';
import '../../../api/api_client.dart';

/// A single activity log entry
class ActivityTile extends StatelessWidget {
  final Activity activity;

  const ActivityTile({super.key, required this.activity});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF2A2A3E).withAlpha(128),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(
            _activityIcon(activity.action),
            size: 16,
            color: _activityColor(activity.action),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  activity.description,
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                ),
                const SizedBox(height: 2),
                Text(
                  _formatTimeAgo(activity.timestamp),
                  style: TextStyle(color: Colors.white.withAlpha(128), fontSize: 11),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  IconData _activityIcon(String action) {
    switch (action) {
      case 'created':
        return Icons.add_circle_outline;
      case 'completed':
      case 'subtask_completed':
        return Icons.check_circle_outline;
      case 'subtask_added':
        return Icons.playlist_add;
      case 'subtask_deleted':
        return Icons.remove_circle_outline;
      case 'subtask_uncompleted':
        return Icons.radio_button_unchecked;
      case 'priority_changed':
        return Icons.flag_outlined;
      case 'updated':
        return Icons.edit_outlined;
      case 'reopened':
        return Icons.replay;
      default:
        return Icons.circle_outlined;
    }
  }

  Color _activityColor(String action) {
    switch (action) {
      case 'created':
      case 'subtask_added':
        return const Color(0xFF6366F1);
      case 'completed':
      case 'subtask_completed':
        return const Color(0xFF10B981);
      case 'subtask_deleted':
        return const Color(0xFFEF4444);
      case 'priority_changed':
        return const Color(0xFFF59E0B);
      default:
        return Colors.white54;
    }
  }

  String _formatTimeAgo(DateTime timestamp) {
    final diff = DateTime.now().difference(timestamp);
    if (diff.inMinutes < 1) {
      return 'Just now';
    } else if (diff.inMinutes < 60) {
      return '${diff.inMinutes}m ago';
    } else if (diff.inHours < 24) {
      return '${diff.inHours}h ago';
    } else {
      return '${diff.inDays}d ago';
    }
  }
}


