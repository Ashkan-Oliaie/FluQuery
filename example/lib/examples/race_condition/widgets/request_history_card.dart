import 'package:flutter/material.dart';
import '../models/request_log.dart';

class RequestHistoryCard extends StatelessWidget {
  final List<RequestLog> history;

  const RequestHistoryCard({super.key, required this.history});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accentColor = Theme.of(context).colorScheme.primary;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark
            ? Color.lerp(const Color(0xFF1A1A2E), accentColor, 0.04)
            : Color.lerp(Colors.white, accentColor, 0.02),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: accentColor.withAlpha(isDark ? 35 : 20)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Request History',
            style: TextStyle(
              color: isDark ? Colors.white70 : Colors.black54,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 80,
            child: history.isEmpty
                ? Center(
                    child: Text(
                      'Type to see requests...',
                      style: TextStyle(
                        color: isDark ? Colors.white38 : Colors.black26,
                      ),
                    ),
                  )
                : ListView.builder(
                    reverse: true,
                    itemCount: history.length,
                    itemBuilder: (context, index) {
                      final log = history[history.length - 1 - index];
                      final color = log.status.color(accentColor);
                      final icon = log.status.icon;
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Row(
                          children: [
                            Icon(icon, size: 14, color: color),
                            const SizedBox(width: 8),
                            Text(
                              '"${log.query}"',
                              style: TextStyle(color: color, fontSize: 12),
                            ),
                            const Spacer(),
                            if (log.duration != null)
                              Text(
                                '${log.duration!.inMilliseconds}ms',
                                style: TextStyle(
                                  color:
                                      isDark ? Colors.white54 : Colors.black38,
                                  fontSize: 10,
                                ),
                              ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
