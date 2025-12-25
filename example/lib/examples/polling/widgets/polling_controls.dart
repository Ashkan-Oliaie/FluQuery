import 'package:flutter/material.dart';
import '../../shared/shared.dart';

/// Controls for polling interval and on/off toggle
class PollingControls extends StatelessWidget {
  final bool isPolling;
  final Duration? pollInterval;
  final ValueChanged<bool> onPollingChanged;
  final ValueChanged<Duration> onIntervalChanged;

  const PollingControls({
    super.key,
    required this.isPolling,
    required this.pollInterval,
    required this.onPollingChanged,
    required this.onIntervalChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accentColor = Theme.of(context).colorScheme.primary;

    return ThemedCard(
      elevated: true,
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Auto Refresh',
                style: TextStyle(
                  color: isDark ? Colors.white : Colors.black87,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Switch(
                value: isPolling,
                onChanged: onPollingChanged,
                activeTrackColor: accentColor,
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Interval: ${pollInterval?.inSeconds ?? 0}s',
                style:
                    TextStyle(color: isDark ? Colors.white60 : Colors.black54),
              ),
              Row(
                children: [1, 3, 5, 10].map((seconds) {
                  final selected = pollInterval?.inSeconds == seconds;
                  return Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: GestureDetector(
                      onTap: () =>
                          onIntervalChanged(Duration(seconds: seconds)),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: selected
                              ? accentColor
                              : (isDark
                                  ? Colors.white.withAlpha(26)
                                  : Colors.black.withAlpha(13)),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '${seconds}s',
                          style: TextStyle(
                            color: selected
                                ? Colors.white
                                : (isDark ? Colors.white60 : Colors.black54),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
