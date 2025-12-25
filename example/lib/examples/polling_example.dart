import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:fluquery/fluquery.dart';
import '../api/api_client.dart';

class PollingExample extends HookWidget {
  const PollingExample({super.key});

  @override
  Widget build(BuildContext context) {
    final pollInterval = useState<Duration?>(const Duration(seconds: 3));
    final isPolling = useState(true);
    final fetchCount = useState(0);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accentColor = Theme.of(context).colorScheme.primary;

    final timeQuery = useQuery<ServerTime, Object>(
      queryKey: ['server-time'],
      queryFn: (_) => ApiClient.getServerTime(),
      refetchInterval: isPolling.value ? pollInterval.value : null,
      staleTime: StaleTime.zero,
    );

    useEffect(() {
      if (timeQuery.isSuccess) {
        fetchCount.value++;
      }
      return null;
    }, [timeQuery.dataUpdatedAt]);

    return Scaffold(
      appBar: AppBar(title: const Text('Polling')),
      body: Container(
        decoration: BoxDecoration(
          gradient: isDark
              ? const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFF0F0F1A), Color(0xFF1A1A2E)],
                )
              : LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.grey.shade50, Colors.white],
                ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              // Controls
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: isDark
                      ? Color.lerp(const Color(0xFF1A1A2E), accentColor, 0.05)
                      : Color.lerp(Colors.white, accentColor, 0.03),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                      color: accentColor.withAlpha(isDark ? 40 : 25)),
                  boxShadow: [
                    BoxShadow(
                      color: accentColor.withAlpha(isDark ? 15 : 20),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
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
                          value: isPolling.value,
                          onChanged: (v) => isPolling.value = v,
                          activeTrackColor: accentColor,
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Interval: ${pollInterval.value?.inSeconds ?? 0}s',
                          style: TextStyle(
                              color: isDark ? Colors.white60 : Colors.black54),
                        ),
                        Row(
                          children: [1, 3, 5, 10].map((seconds) {
                            final selected =
                                pollInterval.value?.inSeconds == seconds;
                            return Padding(
                              padding: const EdgeInsets.only(left: 8),
                              child: GestureDetector(
                                onTap: () => pollInterval.value =
                                    Duration(seconds: seconds),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 6),
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
                                          : (isDark
                                              ? Colors.white60
                                              : Colors.black54),
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
              ),
              const SizedBox(height: 24),
              Expanded(
                child: Center(
                  child: _buildTimeDisplay(
                      context, timeQuery, isPolling.value, fetchCount.value),
                ),
              ),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed:
                      timeQuery.isFetching ? null : () => timeQuery.refetch(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: accentColor,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: timeQuery.isFetching
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.refresh),
                  label: const Text('Manual Refresh'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTimeDisplay(
    BuildContext context,
    QueryResult<ServerTime, Object> query,
    bool isPolling,
    int fetchCount,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accentColor = Theme.of(context).colorScheme.primary;

    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: isDark
            ? Color.lerp(const Color(0xFF1A1A2E), accentColor, 0.05)
            : Color.lerp(Colors.white, accentColor, 0.03),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: accentColor.withAlpha(isDark ? 40 : 25)),
        boxShadow: [
          BoxShadow(
            color: accentColor.withAlpha(isDark ? 15 : 20),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
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
          ),
          const SizedBox(height: 24),
          if (query.isLoading && query.data == null)
            CircularProgressIndicator(color: accentColor)
          else if (query.isError)
            Text('Error: ${query.error}',
                style: const TextStyle(color: Colors.red))
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
                  color: isDark ? Colors.white54 : Colors.black45),
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
