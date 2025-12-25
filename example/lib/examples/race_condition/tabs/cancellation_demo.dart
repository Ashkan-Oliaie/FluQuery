import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:fluquery/fluquery.dart';
import '../../../constants/query_keys.dart';
import '../../shared/shared.dart';
import '../widgets/race_info_card.dart';

class ManualCancellationDemo extends HookWidget {
  const ManualCancellationDemo({super.key});

  @override
  Widget build(BuildContext context) {
    final client = useQueryClient();
    final requestKey = useState(0);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accentColor = Theme.of(context).colorScheme.primary;

    final slowQuery = useQuery<String, Object>(
      queryKey: QueryKeys.slowQueryFor(requestKey.value),
      queryFn: (ctx) async {
        for (int i = 0; i < 10; i++) {
          if (ctx.signal?.isCancelled == true) throw QueryCancelledException();
          await Future.delayed(const Duration(seconds: 1));
        }
        return 'Completed after 10 seconds!';
      },
      enabled: requestKey.value > 0,
      retry: 0,
    );

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const RaceInfoCard(
            icon: Icons.cancel,
            title: 'Manual Cancellation',
            description:
                'Start a slow query (10 seconds) and cancel it before completion. '
                'Use CancellationToken to check if the query should stop.',
          ),
          const SizedBox(height: 24),
          Center(
            child: Column(
              children: [
                ElevatedButton.icon(
                  onPressed:
                      slowQuery.isFetching ? null : () => requestKey.value++,
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('Start 10s Query'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: accentColor,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 32,
                      vertical: 16,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: slowQuery.isFetching
                      ? () => client.cancelQueries(
                            queryKey: QueryKeys.slowQueryFor(requestKey.value),
                          )
                      : null,
                  icon: const Icon(Icons.cancel),
                  label: const Text('Cancel Query'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 32,
                      vertical: 16,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          ThemedCard(
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      slowQuery.isFetching
                          ? Icons.hourglass_empty
                          : slowQuery.isSuccess
                              ? Icons.check_circle
                              : slowQuery.isError
                                  ? Icons.error
                                  : Icons.radio_button_unchecked,
                      color: slowQuery.isFetching
                          ? accentColor
                          : slowQuery.isSuccess
                              ? Colors.green
                              : slowQuery.isError
                                  ? Colors.red
                                  : (isDark ? Colors.white38 : Colors.black26),
                      size: 48,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  slowQuery.isFetching
                      ? 'Running... (click Cancel to stop)'
                      : slowQuery.isSuccess
                          ? slowQuery.data ?? 'Done!'
                          : slowQuery.isError
                              ? slowQuery.error is QueryCancelledException
                                  ? 'Cancelled by user!'
                                  : 'Error: ${slowQuery.error}'
                              : 'Click Start to begin',
                  style: TextStyle(
                    color: slowQuery.isFetching
                        ? accentColor
                        : slowQuery.isSuccess
                            ? Colors.green
                            : slowQuery.isError
                                ? Colors.orange
                                : (isDark ? Colors.white54 : Colors.black45),
                    fontSize: 16,
                  ),
                  textAlign: TextAlign.center,
                ),
                if (slowQuery.isFetching) ...[
                  const SizedBox(height: 16),
                  LinearProgressIndicator(color: accentColor),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
