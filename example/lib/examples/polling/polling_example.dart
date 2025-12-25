import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:fluquery/fluquery.dart';
import '../../api/api_client.dart';
import '../shared/shared.dart';
import 'widgets/polling_controls.dart';
import 'widgets/time_display.dart';

class PollingExample extends HookWidget {
  const PollingExample({super.key});

  @override
  Widget build(BuildContext context) {
    final pollInterval = useState<Duration?>(const Duration(seconds: 3));
    final isPolling = useState(true);
    final fetchCount = useState(0);
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
      body: GradientBackground(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              PollingControls(
                isPolling: isPolling.value,
                pollInterval: pollInterval.value,
                onPollingChanged: (v) => isPolling.value = v,
                onIntervalChanged: (d) => pollInterval.value = d,
              ),
              const SizedBox(height: 24),
              Expanded(
                child: Center(
                  child: TimeDisplay(
                    query: timeQuery,
                    isPolling: isPolling.value,
                    fetchCount: fetchCount.value,
                  ),
                ),
              ),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: timeQuery.isFetching ? null : () => timeQuery.refetch(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: accentColor,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: timeQuery.isFetching
                      ? const SmallSpinner(color: Colors.white)
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
}

