import 'package:flutter_hooks/flutter_hooks.dart';
import '../core/types.dart';
import '../core/query_options.dart';
import '../core/query_observer.dart';
import '../widgets/query_client_provider.dart';

/// Configuration for a single query in useQueries
class QueryConfig<TData, TError> {
  final QueryKey queryKey;
  final QueryFn<TData> queryFn;
  final StaleTime staleTime;
  final GcTime gcTime;
  final bool enabled;
  final int retry;

  const QueryConfig({
    required this.queryKey,
    required this.queryFn,
    this.staleTime = StaleTime.zero,
    this.gcTime = GcTime.defaultTime,
    this.enabled = true,
    this.retry = 3,
  });
}

/// Hook for running multiple queries in parallel
List<QueryResult<dynamic, dynamic>> useQueries({
  required List<QueryConfig> queries,
}) {
  final context = useContext();
  final client = QueryClientProvider.of(context);

  // Create observers
  final observers = useMemoized(
    () => queries.map((config) {
      final options = QueryOptions(
        queryKey: config.queryKey,
        queryFn: config.queryFn,
        staleTime: config.staleTime,
        gcTime: config.gcTime,
        enabled: config.enabled,
        retry: config.retry,
      );

      return QueryObserver(
        cache: client.queryCache,
        options: options,
      );
    }).toList(),
    [queries.map((q) => q.queryKey.toString()).join(',')],
  );

  // State for results
  final resultsState = useState<List<QueryResult<dynamic, dynamic>>>(
    observers.map((o) => QueryResult.loading(refetch: () => o.fetch())).toList(),
  );

  // Subscribe to all observers
  useEffect(() {
    final subscriptions = <int, dynamic>{};

    for (var i = 0; i < observers.length; i++) {
      final observer = observers[i];
      final index = i;

      subscriptions[index] = observer.stream.listen((result) {
        final newResults = List<QueryResult<dynamic, dynamic>>.from(resultsState.value);
        newResults[index] = result;
        resultsState.value = newResults;
      });

      // Start observer
      observer.start().then((result) {
        final newResults = List<QueryResult<dynamic, dynamic>>.from(resultsState.value);
        newResults[index] = result;
        resultsState.value = newResults;
      });
    }

    return () {
      for (final sub in subscriptions.values) {
        sub.cancel();
      }
      for (final observer in observers) {
        observer.destroy();
      }
    };
  }, [observers]);

  return resultsState.value;
}

